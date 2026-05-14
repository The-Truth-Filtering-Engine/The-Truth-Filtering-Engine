import { type Session } from '@supabase/supabase-js'
import { useEffect, useMemo, useState } from 'react'
import {
  GOOGLE_AUTH_REDIRECT_TO,
  TEST_ACCOUNT_AUTH_HEADER,
  TEST_ACCOUNT_EMAIL,
} from '../config'
import { supabase } from '../lib/supabase'

const TEST_ACCOUNT_AUTH_STORAGE_KEY = 'truth_filtering_test_account_auth'

type AuthStatus = 'checking' | 'signedOut' | 'signedIn'

export type UseAuthReturn = {
  authSession: Session | null
  authStatus: AuthStatus
  authErrorMessage: string
  isLoggedIn: boolean
  authEmail: string
  authHeaders: Record<string, string>
  authKey: string
  hasApiAuth: boolean
  signInWithGoogle: () => Promise<void>
  signInWithTestAccount: () => void
  signOut: () => Promise<void>
}

export function useAuth(onSignOut: () => void, showToast: (message: string) => void): UseAuthReturn {
  const [authSession, setAuthSession] = useState<Session | null>(null)
  const [authStatus, setAuthStatus] = useState<AuthStatus>('checking')
  const [authErrorMessage, setAuthErrorMessage] = useState('')
  const [isTestAccountLogin, setIsTestAccountLogin] = useState(false)

  const authEmail = authSession?.user?.email?.trim() || (isTestAccountLogin ? TEST_ACCOUNT_EMAIL : '')
  const authKey = authSession?.access_token || (isTestAccountLogin ? TEST_ACCOUNT_EMAIL : '')
  const authHeaders = useMemo<Record<string, string>>(() => {
    if (authSession?.access_token) {
      return { Authorization: `Bearer ${authSession.access_token}` } as Record<string, string>
    }
    if (isTestAccountLogin) {
      return { [TEST_ACCOUNT_AUTH_HEADER]: TEST_ACCOUNT_EMAIL } as Record<string, string>
    }
    return {} as Record<string, string>
  }, [authSession?.access_token, isTestAccountLogin])
  const hasApiAuth = authKey !== ''
  const isLoggedIn = authSession !== null || isTestAccountLogin

  useEffect(() => {
    const storedTestAccount =
      window.localStorage.getItem(TEST_ACCOUNT_AUTH_STORAGE_KEY) === 'true'
    setIsTestAccountLogin(storedTestAccount)

    if (!supabase) {
      setAuthStatus(storedTestAccount ? 'signedIn' : 'signedOut')
      if (!storedTestAccount) onSignOut()
      return
    }

    let isMounted = true

    supabase.auth.getSession().then(({ data, error }) => {
      if (!isMounted) return

      if (error) {
        setAuthErrorMessage(error.message)
      }
      const session = data.session ?? null
      setAuthSession(session)
      setAuthStatus(session || storedTestAccount ? 'signedIn' : 'signedOut')
      if (!session && !storedTestAccount) {
        onSignOut()
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthSession(session)
      setAuthStatus(session ? 'signedIn' : 'signedOut')
      if (session) {
        setIsTestAccountLogin(false)
        window.localStorage.removeItem(TEST_ACCOUNT_AUTH_STORAGE_KEY)
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

  function signInWithTestAccount() {
    window.localStorage.setItem(TEST_ACCOUNT_AUTH_STORAGE_KEY, 'true')
    setIsTestAccountLogin(true)
    setAuthErrorMessage('')
    setAuthStatus('signedIn')
    showToast(`${TEST_ACCOUNT_EMAIL} 계정으로 로그인되었습니다`)
  }

  async function signOut() {
    try {
      if (supabase && authSession) {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
      }

      window.localStorage.removeItem(TEST_ACCOUNT_AUTH_STORAGE_KEY)
      setIsTestAccountLogin(false)
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
    isLoggedIn,
    authEmail,
    authHeaders,
    authKey,
    hasApiAuth,
    signInWithGoogle,
    signInWithTestAccount,
    signOut,
  }
}
