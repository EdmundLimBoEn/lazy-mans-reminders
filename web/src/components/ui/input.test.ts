import { expect, it } from 'vitest'
import { Input } from './input'

it('turns off browser autofill unless a caller opts in', () => {
  expect(Input({}).props.autoComplete).toBe('off')
  expect(Input({ type: 'email', autoComplete: 'email' }).props.autoComplete).toBe('email')
})
