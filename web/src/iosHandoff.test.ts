import { describe, expect, it } from 'vitest'
import { IOS_APP_CALLBACK, iosHandoffFromLocation } from './iosHandoff'

describe('iosHandoffFromLocation', () => {
  it.each([
    'https://np.sillyapps.co/auth/ios?code=abc123',
    'https://lmr.sillyapps.co/auth/ios?code=abc123',
  ])('forwards a PKCE code from %s onto the app callback', (href) => {
    const result = iosHandoffFromLocation(href)
    expect(result).toEqual({
      status: 'open',
      href: `${IOS_APP_CALLBACK}?code=abc123`,
    })
  })

  it('forwards only the names the app callback accepts', () => {
    const result = iosHandoffFromLocation(
      'https://lmr.sillyapps.co/auth/ios?code=abc&type=magiclink#sb=',
    )
    expect(result).toEqual({
      status: 'open',
      href: `${IOS_APP_CALLBACK}?code=abc&type=magiclink#sb=`,
    })
  })

  it('does not copy implicit tokens onto the app callback', () => {
    expect(
      iosHandoffFromLocation(
        'https://lmr.sillyapps.co/auth/ios?code=abc&access_token=stolen#refresh_token=stolen',
      ),
    ).toEqual({
      status: 'open',
      href: `${IOS_APP_CALLBACK}?code=abc`,
    })
    expect(
      iosHandoffFromLocation(
        'https://lmr.sillyapps.co/auth/ios#access_token=stolen&refresh_token=stolen&expires_in=3600&token_type=bearer',
      ),
    ).toEqual({ status: 'empty' })
  })

  it('does not open the app when an allowed name is duplicated', () => {
    expect(
      iosHandoffFromLocation('https://lmr.sillyapps.co/auth/ios?code=one#code=two'),
    ).toEqual({ status: 'empty' })
  })

  it('surfaces GoTrue error_description instead of opening the app', () => {
    const result = iosHandoffFromLocation(
      'https://lmr.sillyapps.co/auth/ios#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired&sb=',
    )
    expect(result).toEqual({
      status: 'error',
      message: 'Email link is invalid or has expired',
    })
  })

  it('treats a bare landing URL as empty', () => {
    expect(iosHandoffFromLocation('https://lmr.sillyapps.co/auth/ios')).toEqual({
      status: 'empty',
    })
  })
})
