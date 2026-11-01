import { afterEach, expect, it, vi } from 'vitest'
import { connectionRefresh } from './connectionRefresh'

afterEach(() => vi.unstubAllGlobals())

it('coalesces overlapping recovery signals into one follow-up read', async () => {
  const browser = new EventTarget()
  vi.stubGlobal('window', browser)
  let finish!: () => void
  const load = vi.fn().mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve }))
    .mockResolvedValue(undefined)
  const recovery = connectionRefresh(load, vi.fn())
  for (let i = 0; i < 20; i++) {
    browser.dispatchEvent(new Event('online'))
    recovery.onStatus('SUBSCRIBED')
  }
  expect(load).toHaveBeenCalledTimes(1)
  finish()
  await vi.waitFor(() => expect(load).toHaveBeenCalledTimes(2))
  recovery.dispose()
})

it('retains pending recovery after a rejected read and cancels queued work on disposal', async () => {
  vi.stubGlobal('window', new EventTarget())
  let reject!: (error: Error) => void
  let finish!: () => void
  const error = new Error('Offline')
  const onError = vi.fn()
  const load = vi.fn().mockImplementationOnce(() => new Promise<void>((_, fail) => { reject = fail }))
    .mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve }))
  const recovery = connectionRefresh(load, onError)
  recovery.onStatus('SUBSCRIBED')
  reject(error)
  await vi.waitFor(() => expect(load).toHaveBeenCalledTimes(2))
  expect(onError).toHaveBeenCalledWith(error)
  recovery.refresh()
  recovery.dispose()
  finish()
  await Promise.resolve()
  expect(load).toHaveBeenCalledTimes(2)
})
