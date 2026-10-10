import type { ReactNode } from 'react'
import { useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { GripVertical } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

export function SortableReminder({ id, text, disabled, showHandle, children }: {
  id: string
  text: string
  disabled: boolean
  showHandle: boolean
  children: ReactNode
}) {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({ id, disabled })

  return (
    <li
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={cn('relative flex min-h-14 items-center gap-1 py-1.5 pr-1.5 pl-1.5', isDragging && 'z-10 rounded-md bg-background shadow-md')}
    >
      {showHandle && (
        <Button
          ref={setActivatorNodeRef}
          variant="ghost"
          size="icon"
          type="button"
          className="shrink-0 touch-none cursor-grab text-muted-foreground active:cursor-grabbing"
          disabled={disabled}
          {...attributes}
          {...listeners}
          aria-label={`Drag "${text}" to reorder`}
          title="Drag to reorder. Or press Space, use arrow keys, then Space to drop."
        >
          <GripVertical aria-hidden="true" />
        </Button>
      )}
      {children}
    </li>
  )
}
