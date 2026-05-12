import { type Session } from '@supabase/supabase-js'
import { useEffect, useState } from 'react'
import { GOOGLE_AUTH_REDIRECT_TO } from '../config'
import { supabase } from '../lib/supabase'

const TEMP_ADMIN_AUTH_STORAGE_KEY = 'truth_filtering_temp_admin_auth'

type AuthStatus = 'checking' | 'signedOut' | 'signedIn'

export type UseAuthReturn = {
  authSession: Session | null
  authStatus: AuthStatus
  authErrorMessage: string
  isTemporaryAdmin: boolean
  isLoggedIn: boolean
  signInWithGoogle: () => Promise<void>
  signInAsTemporaryAdmin: () => void
  signOut: () => Promise<void>
}

export function useAuth(onSignOut: () => void, showToast: (message: string) => void): UseAuthReturn {
  const [authSession, setAuthSession] = useState<Session | null>(null)
  const [authStatus, setAuthStatus] = useState<AuthStatus>('checking')
  const [authErrorMessage, setAuthErrorMessage] = useState('')
  const [isTemporaryAdmin, setIsTemporaryAdmin] = useState(false)

  const isLoggedIn = authSession !== null || isTemporaryAdmin

  useEffect(() => {
    setIsTemporaryAdmin(
      window.localStorage.getItem(TEMP_ADMIN_AUTH_STORAGE_KEY) === 'true',
    )

    if (!supabase) {
      setAuthStatus('signedOut')
      onSignOut()
      return
    }

    let isMounted = true

    supabase.auth.getSession().then(({ data, error }) => {
      if (!isMounted) return

      if (error) {
        setAuthErrorMessage(error.message)
      }
      setAuthSession(data.session ?? null)
      setAuthStatus(data.session ? 'signedIn' : 'signedOut')
      if (!data.session) {
        onSignOut()
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthSession(session)
      setAuthStatus(session ? 'signedIn' : 'signedOut')
      if (session) {
        setIsTemporaryAdmin(false)
        window.localStorage.removeItem(TEMP_ADMIN_AUTH_STORAGE_KEY)
      } else {
        onSignOut()
      }
    })

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  async function signInWithGoogle() {
    if (!supabase) {
      setAuthErrorMessage(
        'Supabase 로그인 설정이 없습니다. VITE_SUPABASE_URL과 VITE_SUPABASE_ANON_KEY를 확인해 주세요.',
      )
      return
    }

    setAuthErrorMessage('')
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: GOOGLE_AUTH_REDIRECT_TO },
    })

    if (error) {
      setAuthErrorMessage(error.message)
      showToast('Google 로그인을 시작하지 못했습니다')
    }
  }

  function signInAsTemporaryAdmin() {
    window.localStorage.setItem(TEMP_ADMIN_AUTH_STORAGE_KEY, 'true')
    setIsTemporaryAdmin(true)
    setAuthErrorMessage('')
    setAuthStatus('signedIn')
    showToast('관리자 임시 로그인 상태입니다')
  }

  async function signOut() {
    try {
      if (supabase && authSession) {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
      }

      window.localStorage.removeItem(TEMP_ADMIN_AUTH_STORAGE_KEY)
      setIsTemporaryAdmin(false)
      setAuthSession(null)
      setAuthStatus('signedOut')
      onSignOut()
      showToast('로그아웃되었습니다')
    } catch {
      showToast('로그아웃하지 못했습니다')
    }
  }

  return {
    authSession,
    authStatus,
    authErrorMessage,
    isTemporaryAdmin,
    isLoggedIn,
    signInWithGoogle,
    signInAsTemporaryAdmin,
    signOut,
  }
}
