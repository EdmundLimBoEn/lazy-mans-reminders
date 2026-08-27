import { describe, expect, it } from 'vitest'
import { IOS_APP_CALLBACK, iosHandoffFromLocation } from './iosHandoff'

describe('iosHandoffFromLocation', () => {
  it('forwards a PKCE code onto the app callback', () => {
    const result = iosHandoffFromLocation(
      'https://lmr.edmundlim.systems/auth/ios?code=abc123',
    )
    expect(result).toEqual({
      status: 'open',
      href: `${IOS_APP_CALLBACK}?code=abc123`,
    })
  })

  it('keeps extra query params and the hash fragment', () => {
    const result = iosHandoffFromLocation(
      'https://lmr.edmundlim.systems/auth/ios?code=abc&type=magiclink#sb=',
    )
    expect(result).toEqual({
      status: 'open',
      href: `${IOS_APP_CALLBACK}?code=abc&type=magiclink#sb=`,
    })
  })

  it('surfaces GoTrue error_description instead of opening the app', () => {
    const result = iosHandoffFromLocation(
      'https://lmr.edmundlim.systems/auth/ios#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired&sb=',
    )
    expect(result).toEqual({
      status: 'error',
      message: 'Email link is invalid or has expired',
    })
  })

  it('treats a bare landing URL as empty', () => {
    expect(iosHandoffFromLocation('https://lmr.edmundlim.systems/auth/ios')).toEqual({
      status: 'empty',
    })
  })
})
