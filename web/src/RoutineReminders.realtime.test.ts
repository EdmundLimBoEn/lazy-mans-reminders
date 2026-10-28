import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { RoutineReminders } from './RoutineReminders'

const hooks = vi.hoisted(() => ({ effect: undefined as undefined | (() => () => void) }))
const db = vi.hoisted(() => ({ from: vi.fn(), channel: vi.fn(), removeChannel: vi.fn() }))
vi.mock('./supabase', () => ({ supabase: db }))
vi.mock('react', async (importOriginal) => ({
  ...await importOriginal<typeof import('react')>(),
  useState: (initial: unknown) => [typeof initial === 'function' ? initial() : initial, vi.fn()],
  useRef: (initial: unknown) => ({ current: initial }),
  useCallback: (callback: unknown) => callback,
  useEffect: (effect: () => () => void) => { hooks.effect = effect },
}))

let notify: () => void
let cleanup: () => void
let order: ReturnType<typeof vi.fn>
let channel: { on: ReturnType<typeof vi.fn>; subscribe: ReturnType<typeof vi.fn> }

beforeEach(() => {
  vi.stubGlobal('window', new EventTarget())
  vi.useFakeTimers()
  vi.clearAllMocks()
  order = vi.fn().mockResolvedValue({ data: [], error: null })
  db.from.mockReturnValue({ select: () => ({ eq: () => ({ order }) }) })
  channel = { on: vi.fn(), subscribe: vi.fn() }
  channel.on.mockImplementation((_event, _filter, callback) => { notify = callback; return channel })
  channel.subscribe.mockReturnValue(channel)
  db.channel.mockReturnValue(channel)
  RoutineReminders({ userId: 'user-1' })
  cleanup = hooks.effect!()
})

afterEach(() => {
  cleanup()
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

it('debounces a 50-event burst into one full-list read after the last event', async () => {
  await vi.advanceTimersByTimeAsync(0)
  expect(order).toHaveBeenCalledTimes(1)
  for (let i = 0; i < 50; i++) {
    notify()
    await vi.advanceTimersByTimeAsync(10)
  }
  expect(order).toHaveBeenCalledTimes(1)
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(2)
})

it.each(['success', 'database error', 'rejection'])('coalesces events during a pending read and releases the gate after %s', async (outcome) => {
  await vi.advanceTimersByTimeAsync(0)
  let resolve!: (value: unknown) => void
  let reject!: (error: Error) => void
  order.mockReturnValueOnce(new Promise((done, fail) => { resolve = done; reject = fail }))
  notify()
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(2)
  for (let i = 0; i < 50; i++) notify()
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(2)
  if (outcome === 'rejection') reject(new Error('Offline'))
  else resolve({ data: [], error: outcome === 'database error' ? { message: 'Offline' } : null })
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(3)
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(3)
  notify()
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(4)
})

it('cancels a debounced refresh and ignores late callbacks after cleanup', async () => {
  await vi.advanceTimersByTimeAsync(0)
  notify()
  cleanup()
  notify()
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(1)
  expect(db.removeChannel).toHaveBeenCalledWith(channel)
})

it('does not launch a queued follow-up when an in-flight read finishes after cleanup', async () => {
  await vi.advanceTimersByTimeAsync(0)
  let resolve!: (value: unknown) => void
  order.mockReturnValueOnce(new Promise(done => { resolve = done }))
  notify()
  await vi.advanceTimersByTimeAsync(100)
  notify()
  cleanup()
  resolve({ data: [], error: null })
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(2)
})

it('queues notifications received before the initial read settles', async () => {
  // The immediate initial query has started, but its promise has not settled yet.
  for (let i = 0; i < 50; i++) notify()
  expect(order).toHaveBeenCalledTimes(1)
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(2)
})

it.each(['SUBSCRIBED', 'online'])('queues %s recovery before the initial read settles', async trigger => {
  for (let i = 0; i < 50; i++) {
    if (trigger === 'online') window.dispatchEvent(new Event('online'))
    else channel.subscribe.mock.calls[0][0]('SUBSCRIBED')
  }
  expect(order).toHaveBeenCalledTimes(1)
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(2)
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(2)
})

it.each(['SUBSCRIBED', 'online'])('coalesces %s recovery with row events during an in-flight read', async trigger => {
  await vi.advanceTimersByTimeAsync(0)
  const recover = () => {
    if (trigger === 'online') window.dispatchEvent(new Event('online'))
    else channel.subscribe.mock.calls[0][0]('SUBSCRIBED')
  }
  let resolve!: (value: unknown) => void
  order.mockReturnValueOnce(new Promise(done => { resolve = done }))
  notify()
  recover()
  // Recovery immediately consumes the scheduled read.
  expect(order).toHaveBeenCalledTimes(2)
  for (let i = 0; i < 50; i++) { notify(); recover() }
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(2)
  resolve({ data: [], error: null })
  await vi.advanceTimersByTimeAsync(100)
  expect(order).toHaveBeenCalledTimes(3)
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(3)
  cleanup()
  recover()
  await vi.advanceTimersByTimeAsync(1000)
  expect(order).toHaveBeenCalledTimes(3)
})
