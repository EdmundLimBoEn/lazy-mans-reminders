Native investigation uses Apple’s documented setContentScrollView(_:for:) on the collection view’s owning UIViewController. The API assigns the scroll view that navigation bars observe at the specified edge. Source: https://developer.apple.com/documentation/uikit/uiviewcontroller/setcontentscrollview(_:for:)

Probe native binding before any fallback. A public binding flag is not proof: capture actual pulled/scrolled raster, measure first 14 pixel rows relative to listViewport, compare existing round4 originals. Preserve failed attempts.

Written by gpt-6.1-sol in Codex on behalf of Edmund
