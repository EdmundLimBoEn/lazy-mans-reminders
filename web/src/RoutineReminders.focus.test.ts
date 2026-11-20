// @vitest-environment happy-dom
import { act, createElement } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'
import { RoutineReminders } from './RoutineReminders'

const routine = {
  id: 'routine-1', text: 'Prepare Tuesday’s uniform', interval_days: 7, start_date: '2026-11-16',
  local_time: '19:00', timezone: 'Asia/Singapore', enabled: true, next_run_at: '2026-11-23T11:00:00Z',
}

vi.mock('./supabase', () => ({
  supabase: {
    from: () => ({ select: () => ({ eq: () => ({ order: async () => ({ data: [routine], error: null }) }) }) }),
    channel: () => ({ on: () => ({ subscribe: () => ({}) }) }),
    removeChannel: vi.fn(),
  },
}))

it.each([
  ['Enter', 'Enter', 'keydown'],
  ['Space', ' ', 'keyup'],
])('focuses the populated Reminder input when Edit is activated with %s', async (code, key, eventType) => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true)
  const container = document.body.appendChild(document.createElement('div'))
  const root = createRoot(container)
  try {
    await act(async () => root.render(createElement(RoutineReminders, { userId: 'user-1' })))
    const input = container.querySelector<HTMLInputElement>('#routine-text')!
    const edit = Array.from(container.querySelectorAll<HTMLButtonElement>('li button')).find(button => button.textContent === 'Edit')!
    expect(input.value).toBe('')
    edit.focus()
    expect(document.activeElement).toBe(edit)

    await act(() => {
      // Happy DOM leaves the native button activation to the test.
      if (edit.dispatchEvent(new KeyboardEvent(eventType, { key, code, bubbles: true, cancelable: true }))) {
        edit.click()
      }
    })

    expect(input.value).toBe(routine.text)
    expect(document.activeElement).toBe(input)
  } finally {
    await act(() => root.unmount())
    container.remove()
    vi.unstubAllGlobals()
  }
})
