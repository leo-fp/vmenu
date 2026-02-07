"MIT License
"
"Copyright (c) 2025-2026 leo-fp
"
"Permission is hereby granted, free of charge, to any person obtaining a copy
"of this software and associated documentation files (the "Software"), to deal
"in the Software without restriction, including without limitation the rights
"to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"copies of the Software, and to permit persons to whom the Software is
"furnished to do so, subject to the following conditions:
"
"The above copyright notice and this permission notice shall be included in all
"copies or substantial portions of the Software.
"
"THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
"SOFTWARE.

"-------------------------------------------------------------------------------
" constants
"-------------------------------------------------------------------------------
let s:CASCADE_CLOSE = 1
let s:CLOSE_SELF_ONLY = 0
let s:NOT_IN_AREA = 2
let s:RECURSIVE_CLOSE = 3   " close a window and its sub window
let s:ITEM_PATH_SEP = ' > '
let g:VMENU#ITEM_VERSION = #{QUICKUI: 1, VMENU: 2}

"-------------------------------------------------------------------------------
" config
"-------------------------------------------------------------------------------
let s:enable_log = get(g:, "vmenu_enable_log", 0)
let s:enable_echo_tips = get(g:, "vmenu_enable_echo_tips", 1)
let s:enable_mouse_hover = get(g:, "vmenu_enable_mouse_hover", 0)
let s:min_context_menu_width = get(g:, "vmenu_min_context_menu_width", 0)
let s:doc_window_scroll_down_key = get(g:, "vmenu_doc_window_scroll_down_key", "\<C-E>")
let s:doc_window_scroll_up_key = get(g:, "vmenu_doc_window_scroll_up_key", "\<C-Y>")
let s:enable_markdown_syntax_in_doc_window = get(g:, "vmenu_enable_markdown_syntax_in_doc_window", 0)

"-------------------------------------------------------------------------------
" class HotKey
"-------------------------------------------------------------------------------
let s:HotKey = {}
function! s:HotKey.new(keyChar, offset)
    let hotKey = deepcopy(s:HotKey, 1)
    let hotKey.keyChar = a:keyChar
    let hotKey.code = char2nr(a:keyChar)
    let hotKey.offset = a:offset    " the index in context item list
    return hotKey
endfunction

"-------------------------------------------------------------------------------
" class CallbackItemParam
"-------------------------------------------------------------------------------
let s:CallbackItemParam = {}
function! s:createCallbackItemParm(contextItem)
    let callbackItemParam = deepcopy(s:CallbackItemParam, 1)
    let callbackItemParam.name = a:contextItem.originName
    return callbackItemParam
endfunction

"-------------------------------------------------------------------------------
" class KeyStrokeEvent
"-------------------------------------------------------------------------------
let s:KeyStrokeEvent = {}
function! s:KeyStrokeEvent.new(key)
    let keyStrokeEvent = deepcopy(s:KeyStrokeEvent, 1)
    let keyStrokeEvent.key = a:key
    return keyStrokeEvent
endfunction

"-------------------------------------------------------------------------------
" class MouseHoverEvent
"-------------------------------------------------------------------------------
let s:MouseHoverEvent = {}
function! s:MouseHoverEvent.new(mousePos=#{screencol: -1, screenrow: -1})
    let mouseHoverEvent = deepcopy(s:MouseHoverEvent, 1)
    let mouseHoverEvent.key = "VMENU_MOUSE_HOVER"
    let mouseHoverEvent.mousepos = a:mousePos
    return mouseHoverEvent
endfunction

"-------------------------------------------------------------------------------
" class MouseClickEvent
"-------------------------------------------------------------------------------
let s:MouseClickEvent = {}
function! s:MouseClickEvent.new(clickPos=#{screencol: -1, screenrow: -1})
    let mouseClickEvent = deepcopy(s:MouseClickEvent, 1)
    let mouseClickEvent.key = "\<LeftMouse>"
    let mouseClickEvent.mousepos = a:clickPos
    return mouseClickEvent
endfunction

"-------------------------------------------------------------------------------
" class SubMenuClosedEvent
"-------------------------------------------------------------------------------
let s:SubMenuClosedEvent = {}
function! s:SubMenuClosedEvent.new(closeCode, event)
    let subMenuCloseEvent = deepcopy(s:SubMenuClosedEvent, 1)
    let subMenuCloseEvent.key = "VMENU_SUB_MENU_CLOSE"
    let subMenuCloseEvent.closeCode = a:closeCode
    let subMenuCloseEvent.event = deepcopy(a:event, 1)
    return subMenuCloseEvent
endfunction

"-------------------------------------------------------------------------------
" class RecursiveCloseEvent
"-------------------------------------------------------------------------------
let s:RecursiveCloseEvent = {}
function! s:RecursiveCloseEvent.new()
    let recursiveCloseEvent = deepcopy(s:RecursiveCloseEvent, 1)
    let recursiveCloseEvent.key = "VMENU_RECURSIVE_CLOSE"
    return recursiveCloseEvent
endfunction

"-------------------------------------------------------------------------------
" class ScrollbarUpdateEvent
"-------------------------------------------------------------------------------
let s:ScrollbarUpdateEvent = {}
function! s:ScrollbarUpdateEvent.new(scrolledCnt)
    let scrollbarUpdateEvent = deepcopy(s:ScrollbarUpdateEvent, 1)
    let scrollbarUpdateEvent.key = "SCROLLBAR_UPDATE"
    let scrollbarUpdateEvent.scrolledCnt = a:scrolledCnt
    return scrollbarUpdateEvent
endfunction

"-------------------------------------------------------------------------------
" color
"-------------------------------------------------------------------------------
hi! VmenuBg guifg=#BEC0C6 guibg=#2B2D30
hi! VmenuSelect guibg=#2E436E guifg=#BCBCAC
hi! VmenuDesc guifg=#465967
hi! VmenuSepLine guifg=#393B3F
hi! VmenuInactive guifg=#4D5360
hi! VmenuHotkey1 gui=underline guifg=#BEC0C6
hi! VmenuSelectedHotkey gui=underline guibg=#2E436E guifg=#BEC0C6
hi! VmenuInactiveHotKey gui=underline guifg=#4D5360
hi! VmenuScrollbar guibg=#4D4D4F guifg=#4D4D4F
hi! VmenuDocWindowScrollbar guibg=#67676A guifg=#67676A " thumb highlight
hi! VmenuDocWindow guifg=#BEC0C6 guibg=#565656

"-------------------------------------------------------------------------------
" class VmenuWindowBuilder
"-------------------------------------------------------------------------------
let s:VmenuWindowBuilder = {}
function! s:VmenuWindowBuilder.new()
    let vmenuWindowBuilder = deepcopy(s:VmenuWindowBuilder, 1)
    let vmenuWindowBuilder.__delayTime           = 0    " delay time (seconds) before handling key stroke
    let vmenuWindowBuilder.__parentContextWindow = {}   " parent vmenu window
    let vmenuWindowBuilder.__goPreviousKey       = 'k'  " key to focus previous item
    let vmenuWindowBuilder.__goNextKey           = 'j'  " key to focus next item
    let vmenuWindowBuilder.__closeKey            = "\<ESC>" "key to close vmenu window
    let vmenuWindowBuilder.__confirmKey          = "\<CR>" " key to enter item
    let vmenuWindowBuilder.__goBottomKey         = 'G'  " key to go bottom
    let vmenuWindowBuilder.__x                   = 0    " column number
    let vmenuWindowBuilder.__y                   = 0    " line number
    let vmenuWindowBuilder.__errConsumer = function("s:printWarn")
    let vmenuWindowBuilder.__minWidth = s:min_context_menu_width   " minimal window width. only supported in context menu
    let vmenuWindowBuilder.__editorStatusSupplier = function("s:getEditorStatus")
    let vmenuWindowBuilder.__winHeight = 20    " maxmium window width. only supported in context menu
    return vmenuWindowBuilder
endfunction
function! s:VmenuWindowBuilder.delay(seconds)
    let self.__delayTime = a:seconds
    return self
endfunction
function! s:VmenuWindowBuilder.parentVmenuWindow(parentVmenuWindow)
    let self.__parentContextWindow = a:parentVmenuWindow
    return self
endfunction
function! s:VmenuWindowBuilder.prevKey(key)
    let self.__goPreviousKey = a:key
    return self
endfunction
function! s:VmenuWindowBuilder.nextKey(key)
    let self.__goNextKey = a:key
    return self
endfunction
function! s:VmenuWindowBuilder.closeKey(key)
    let self.__closeKey = a:key
    return self
endfunction
function! s:VmenuWindowBuilder.bottomKey(key)
    let self.__goBottomKey = a:key
    return self
endfunction
function! s:VmenuWindowBuilder.errConsumer(errConsumer)
    let self.__errConsumer = a:errConsumer
    return self
endfunction
function! s:VmenuWindowBuilder.minWidth(width)
    let self.__minWidth = a:width
    return self
endfunction
function! s:VmenuWindowBuilder.winHeight(winHeight)
    let self.__winHeight = a:winHeight
    return self
endfunction
function! s:VmenuWindowBuilder.editorStatusSupplier(editorStatusSupplier)
    let self.__editorStatusSupplier = a:editorStatusSupplier
    return self
endfunction
function! s:VmenuWindowBuilder.build()
endfunction

"-------------------------------------------------------------------------------
" class VmenuWindow extends EventHandler implements dumpContent. base class
"-------------------------------------------------------------------------------
let s:VmenuWindow = {}
function! s:VmenuWindow.new()
    let vmenuWindow = s:EventHandler.new()
    call extend(vmenuWindow, deepcopy(s:VmenuWindow, 1), "force")
    let vmenuWindow.dumpContent = function("s:dumpContent")
    let vmenuWindow.hotKeyList = []
    let vmenuWindow.isOpen = 0
    let vmenuWindow.x = -1 " column number
    let vmenuWindow.y = -1 " line number
    let vmenuWindow.winWidth = 0    " visible window width
    let vmenuWindow.winHeight = 0    " visible window height
    let vmenuWindow.__goPreviousKey = 'l'
    let vmenuWindow.__goNextKey = 'h'
    let vmenuWindow.__closeKey            = "\<ESC>" " key to close vmenu window
    let vmenuWindow.__confirmKey          = "\<CR>" " key to enter item
    let vmenuWindow.__goBottomKey = ''
    let vmenuWindow.__errConsumer = function("s:printWarn")
    let vmenuWindow.__curItemIndex = -1
    let vmenuWindow.__componentLength = 0
    let vmenuWindow.parentVmenuWindow = {}  " parent vmenu window instance
    let vmenuWindow.subVmenuWindow = {}     " sub vmenu window instance"
    let vmenuWindow.docWindow = {}          " doc window instance
    return vmenuWindow
endfunction
function! s:VmenuWindow.focusNext()
    let searchSeq = range(self.__curItemIndex+1, max([0, self.__componentLength-1]))
    call self.__focusFirstMatch(searchSeq)
endfunction
function! s:VmenuWindow.focusPrev()
    let reverseSeq = reverse(range(self.__curItemIndex))
    call self.__focusFirstMatch(reverseSeq)
endfunction
function! s:VmenuWindow.__focusFirstMatch(searchSeq)
    let i = indexof(a:searchSeq, {i, v -> self.canBeFocused(v)})
    if i != -1
        call self.focusItemByIndex(a:searchSeq[i])
    else
        " no valid item. do nothing
    endif
endfunction
function! s:VmenuWindow.focusItemByIndex(index)
endfunction
function! s:VmenuWindow.focusBottom()
endfunction
function! s:VmenuWindow.canBeFocused(idx)
    " can be focus by default
    return 1
endfunction
" enter focused item. open sub menu or execute cmd
function! s:VmenuWindow.enter()
endfunction
function! s:VmenuWindow.getCurItem()
endfunction
function! s:VmenuWindow.executeByHotKey(char)
    let idx = indexof(self.hotKeyList, {i, v -> v.keyChar == a:char})
    if idx == -1
        return
    endif

    if self.canBeFocused(self.hotKeyList[idx].offset) == 0
        call self.__errConsumer("vmenu: no executable item for hotkey '" .. a:char .. "'")
        return
    endif

    call self.focusItemByIndex(self.hotKeyList[idx].offset)
    call self.enter()
endfunction
function! s:VmenuWindow.executeByLeftMouse(mouseClickEvent)
    " calculate index of clicked item
    let clickedIdx = self.getItemIndexOnPos(a:mouseClickEvent.mousepos)
    call s:log(self.winId .. " will focus at: " .. clickedIdx)

    if clickedIdx == -1
        call self.close(s:NOT_IN_AREA, a:mouseClickEvent)
    endif

    if clickedIdx != -1 && !self.canBeFocused(clickedIdx)
        return
    endif

    if clickedIdx != -1
        " focus the item
        call self.focusItemByIndex(clickedIdx)

        " enter
        call self.enter()
    endif
endfunction
function! s:VmenuWindow.close(closeCode, event={})
    if a:closeCode == s:RECURSIVE_CLOSE && !empty(self.subVmenuWindow)
        call self.subVmenuWindow.handleEvent(s:RecursiveCloseEvent.new())
    endif

    call self.quickuiWindow.close()
    let self.isOpen = 0
    if !empty(self.docWindow)
        call self.docWindow.close()
    endif
    call s:log("winid: " .. self.winId .. " closed")
    if has_key(self, 'parentVmenuWindow') && !empty(self.parentVmenuWindow)
        call self.parentVmenuWindow.handleEvent(s:SubMenuClosedEvent.new(a:closeCode, a:event))
    endif

    " root window, stop getting user input
    if !has_key(self, 'parentVmenuWindow') || empty(self.parentVmenuWindow)
        call s:VMenuManager.stopListen()
        " make sure no vmenu item tips left
        echo vmenu#itemTips()
    endif

    if has_key(self, 'scrollbarWindow') && !empty(self.scrollbarWindow)
        call self.scrollbarWindow.handleEvent(#{key: "SCROLLBAR_CLOSE"})
    endif
endfunction

function! s:VmenuWindow.__onSubMenuClose(closeCode, event)
    if a:closeCode == s:RECURSIVE_CLOSE
        return
    elseif a:closeCode == s:CASCADE_CLOSE
        call self.close(s:CASCADE_CLOSE)
    else
        call s:VMenuManager.setFocusedWindow(self)
        " this will refresh tips in statusline
        call self.focusItemByIndex(self.__curItemIndex)
    endif

    " the s:NOT_IN_AREA means a mouse click event occured not in sub window.
    " let parent window try to handle this.
    if a:closeCode == s:NOT_IN_AREA
        call self.handleEvent(a:event)
    endif
endfunction

" return: item index in context item list. if there is no valid item, return -1
function! s:VmenuWindow.getItemIndexOnPos(mousePos)
endfunction

function! s:VmenuWindow.__onMouseHover(event)
    let itemIdxAtMousePos = self.getItemIndexOnPos(a:event.mousepos)

    if !self.canBeFocused(itemIdxAtMousePos)
        call self.__renderHighlight(-1)
        call s:VMenuManager.setFocusedWindow(self)

        if !empty(self.docWindow) && self.docWindow.isOpen == 1
            call self.docWindow.handleEvent(#{key: "VMENU_CLOSE_DOC_WINDOW"})
        endif

        if !empty(self.subVmenuWindow) && itemIdxAtMousePos != self.__curItemIndex
            call s:log("winId: " .. self.winId .. " hover at " .. itemIdxAtMousePos)
            call self.subVmenuWindow.handleEvent(s:RecursiveCloseEvent.new())
        endif
    endif

    " not in current window. pass it to parent window
    if itemIdxAtMousePos == -1 && !empty(self.parentVmenuWindow)
        call self.parentVmenuWindow.handleEvent(a:event)
        return
    endif
    if itemIdxAtMousePos == -1
        return
    endif

    " only execute once at same item
    if itemIdxAtMousePos == self.__curItemIndex && !empty(self.subVmenuWindow) && get(self.subVmenuWindow, "isOpen", 0) == 1
        return
    endif

    if !self.canBeFocused(itemIdxAtMousePos)
        return
    endif

    if !empty(self.subVmenuWindow) && itemIdxAtMousePos != self.__curItemIndex
        call s:log("winId: " .. self.winId .. " hover at " .. itemIdxAtMousePos)
        call self.subVmenuWindow.handleEvent(s:RecursiveCloseEvent.new())
    endif
    call s:VMenuManager.setFocusedWindow(self)
    call self.focusItemByIndex(itemIdxAtMousePos)
    let self.subVmenuWindow = self.__expand()
    redraw
endfunction

function! s:VmenuWindow.__expand()
endfunction

"-------------------------------------------------------------------------------
" class EventHandler
"-------------------------------------------------------------------------------
let s:EventHandler = {}
function! s:EventHandler.new()
    let eventHandler = deepcopy(s:EventHandler, 1)
    let eventHandler.__delayTime = 0
    let eventHandler.__actionMap = {}
    let eventHandler.winId = -1 " vmenu window id
    return eventHandler
endfunction
function! s:EventHandler.handleEvent(inputEvent)
    if self.__delayTime != 0
        execute self.__delayTime .. 'sleep'
    endif

    call s:log(printf("winId: %s, event detected: %s", self.winId, s:event2String(a:inputEvent)))
    call self.dispatch(a:inputEvent)
endfunction
function! s:EventHandler.dispatch(inputEvent)
    call get(self.__actionMap, a:inputEvent.key, { -> ''})(a:inputEvent)
endfunction

"-------------------------------------------------------------------------------
" class ContextWindowBuilder extends VmenuWindowBuilder
"-------------------------------------------------------------------------------
let s:ContextWindowBuilder = {}
function! s:ContextWindowBuilder.new()
    let contextWindowBuilder = s:VmenuWindowBuilder.new()
    call extend(contextWindowBuilder, deepcopy(s:ContextWindowBuilder, 1), "force")
    let contextWindowBuilder.__contextItemList = []
    let contextWindowBuilder.__parentContextWindow = {}
    let contextWindowBuilder.__goPreviousKey = 'k'
    let contextWindowBuilder.__goNextKey = 'j'
    let contextWindowBuilder.__closeKey = "\<ESC>"
    let contextWindowBuilder.__confirmKey = "\<CR>"
    let contextWindowBuilder.__goBottomKey = 'G'
    return contextWindowBuilder
endfunction
function! s:ContextWindowBuilder.contextItemList(contextItemList)
    let self.__contextItemList = a:contextItemList
    return self
endfunction
function! s:ContextWindowBuilder.build()
    return s:ContextWindow.new(self)
endfunction


"-------------------------------------------------------------------------------
" class ContextWindow extends VmenuWindow
"-------------------------------------------------------------------------------
let s:ContextWindow = {}
function! s:ContextWindow.builder()
    return s:ContextWindowBuilder.new()
endfunction
function! s:ContextWindow.new(contextWindowBuilder)
    let contextWindow = s:VmenuWindow.new()
    call extend(contextWindow, deepcopy(s:ContextWindow, 1), "force")
    let contextWindow.contextItemList = s:filterVisibleItems(a:contextWindowBuilder.__contextItemList, a:contextWindowBuilder.__editorStatusSupplier())
    let contextWindow.contextItemList = s:ItemParser.__addSurroundedSeparatorLine(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__fillNameToSameLength(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__concatenateShortKey(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__fillNameToSameLength(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__addIcon(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__addPaddingInContextMenu(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__stretchingIfNeed(contextWindow.contextItemList, a:contextWindowBuilder.__minWidth)
    let contextWindow.contextItemList = s:ItemParser.__renderSeparatorLine(contextWindow.contextItemList)
    let contextWindow.quickuiWindow = quickui#window#new()
    let contextWindow.winId = rand(srand())
    let contextWindow.hotKeyList = []
    let contextWindow.winWidth = strwidth(empty(contextWindow.contextItemList) ? 0 : contextWindow.contextItemList[0].name)
    let contextWindow.winHeight = min([a:contextWindowBuilder.__winHeight, contextWindow.contextItemList->len()])
    let contextWindow.renderStartIdx = 0
    let contextWindow.renderEndIdx = min([a:contextWindowBuilder.__winHeight-1, contextWindow.winHeight-1])
    let contextWindow.__componentLength = contextWindow.contextItemList->len()
    let contextWindow.x = a:contextWindowBuilder.__x " column number
    let contextWindow.y = a:contextWindowBuilder.__y " line number
    let contextWindow.__delayTime = a:contextWindowBuilder.__delayTime
    for i in range(len(contextWindow.contextItemList))
        if contextWindow.contextItemList[i].hotKey != ''
            call add(contextWindow.hotKeyList, s:HotKey.new(contextWindow.contextItemList[i].hotKey->tolower(), i))
        endif
    endfor

    let contextWindow.__curItemIndex = -1
    let contextWindow.__errConsumer = a:contextWindowBuilder.__errConsumer
    let contextWindow.__editorStatusSupplier = a:contextWindowBuilder.__editorStatusSupplier
    let contextWindow.isOpen = 0
    let contextWindow.parentVmenuWindow = a:contextWindowBuilder.__parentContextWindow
    let contextWindow.docWindow = {}
    let contextWindow.scrollbarWindow = {}
    call s:log(printf("new ContextWindow created, winId: %s", contextWindow.winId))

    let actionMap = {}
    let actionMap[a:contextWindowBuilder.__closeKey]      = { event -> contextWindow.close(s:CLOSE_SELF_ONLY, s:KeyStrokeEvent.new(a:contextWindowBuilder.__closeKey)) }
    let actionMap[a:contextWindowBuilder.__goNextKey]     = { event -> contextWindow.focusNext() }
    let actionMap[a:contextWindowBuilder.__goPreviousKey] = { event -> contextWindow.focusPrev() }
    let actionMap[a:contextWindowBuilder.__goBottomKey]   = { event -> contextWindow.focusBottom() }
    let actionMap[a:contextWindowBuilder.__confirmKey]    = { event -> contextWindow.enter() }
    let actionMap["\<LeftMouse>"]                         = { mouseClickEvent -> contextWindow.executeByLeftMouse(mouseClickEvent) }
    let actionMap["VMENU_MOUSE_HOVER"]                    = { mouseHoverEvent -> contextWindow.__onMouseHover(mouseHoverEvent) }
    let actionMap["VMENU_SUB_MENU_CLOSE"]                 = { subMenuClosedEvent -> contextWindow.__onSubMenuClose(subMenuClosedEvent.closeCode, subMenuClosedEvent.event) }
    let actionMap["VMENU_RECURSIVE_CLOSE"]                = { event -> contextWindow.close(s:RECURSIVE_CLOSE, {}) }
    for hotKey in contextWindow.hotKeyList
        let actionMap[hotKey.keyChar]                     = { event -> contextWindow.executeByHotKey(event.key) }
    endfor

    let contextWindow.__actionMap = actionMap
    return contextWindow
endfunction
function! s:ContextWindow.getCurItem()
    return self.contextItemList[self.__curItemIndex]
endfunction

" editorStatus: class EditorStautus
function! s:filterVisibleItems(itemList, editorStatus)
    let activeItems = []

    for contextItem in a:itemList
        if get(contextItem, 'isVisible')(a:editorStatus) == 1
            call add(activeItems, deepcopy(contextItem, 1))
        endif
    endfor

    return activeItems
endfunction

" editorStatus: class EditorStautus
function! s:filterQueryableItems(itemList, editorStatus)
    let activeItems = []

    for contextItem in a:itemList
        if get(contextItem, 'isVisible')(a:editorStatus) == 0
                    \ || get(contextItem, 'isInactive')(a:editorStatus) == 1
                    \ || contextItem.isSep == 1
            continue
        endif

        if contextItem.subItemList->empty() && !empty(contextItem.cmd)
            call add(activeItems, deepcopy(contextItem, 1))
        else
            call extend(activeItems,
                        \ s:filterQueryableItems(contextItem.subItemList, a:editorStatus)
                        \ )
        endif
    endfor

    return activeItems
endfunction

" x: column number
" y: line number
function! s:ContextWindow.showAt(x, y)
    if empty(self.contextItemList)
        throw "NoVisibleItemException"
    endif

    let opts = {}
    let text = self.__renderText(0, self.renderEndIdx)
    let opts.h = self.winHeight
    let opts.w = self.winWidth
    let opts.color = "VmenuBg"
    let opts.y = a:y
    let opts.x = a:x

    let win = self.quickuiWindow
    call win.open(text, opts)
    " real position may be different since insufficient space, so read from quickuiWindow
    let self.x = win.x
    let self.y = win.y

    let self.isOpen = 1

    call s:VMenuManager.setFocusedWindow(self)
    call self.__renderHighlight(-1)
    redraw

    call s:log(printf("ContextWindow opened at x:%s, y:%s, vmenu winId: %s,
                \ quickui winId: %s", self.x, self.y, self.winId, self.quickuiWindow.winid))

    let needActivateScrollbar = self.winHeight < self.contextItemList->len()
    if needActivateScrollbar
        let scrollbarWidow = s:ScrollbarWindow.new(self.winHeight, self.contextItemList->len(), 2, "VmenuBg", "VmenuScrollbar")
        call scrollbarWidow.showAt(self.x+self.winWidth-1, self.y)
        let self.scrollbarWindow = scrollbarWidow
    endif
    return self
endfunction
function! s:ContextWindow.showAtCursor()
    let cursorPos = quickui#core#around_cursor(self.winWidth, self.contextItemList->len())
    try
        call self.showAt(cursorPos[1], cursorPos[0])
    catch "NoVisibleItemException"
        " ignore
    endtry

    call self.__focusFirstMatch(range(self.__componentLength))
    return self
endfunction

function! s:ContextWindow.getItemIndexOnPos(mousePos)
    let clickedPos = #{x: a:mousePos.screencol, y: a:mousePos.screenrow}
    let topLeftCorner = s:VMenuManager.calcTopLeftPos(self)
    call s:log("clickedPos:" .. string(clickedPos))
    call s:log("topLeftCorner:" .. string(topLeftCorner))
    if self.isInArea(clickedPos.x, clickedPos.y)
        " plus self.renderStartIdx to correct index if scrollbar is activated
        return clickedPos.y - topLeftCorner.y + self.renderStartIdx
    endif

    return -1
endfunction

" is the position in window
function! s:ContextWindow.isInArea(x, y)
    let topLeftCorner = s:VMenuManager.calcTopLeftPos(self)
    if (topLeftCorner.x <= a:x && a:x <= topLeftCorner.x + self.winWidth) &&
                \ (topLeftCorner.y <= a:y && a:y < topLeftCorner.y + self.winHeight)
        return 1
    else
        return 0
    endif
endfunction

function! s:ContextWindow.focusItemByIndex(index)
    call s:VMenuManager.setFocusedWindow(self)
    let self.__curItemIndex = a:index
    call self.__renderHighlight(a:index)
    call self.__triggerStatuslineRefresh()
    call self.__echoTipsIfEnabled()
    call self.__openDocWindowIfAvaliable()
    call self.__executeCmdField("onFocus")
    redraw
endfunction
function! s:ContextWindow.__triggerStatuslineRefresh()
    if has('nvim') == 1
lua << EOF
    if package.loaded['lualine'] then
        require('lualine').refresh({
            force = true,       -- do an immidiate refresh
            scope = 'tabpage',  -- scope of refresh all/tabpage/window
            place = { 'statusline', 'winbar', 'tabline' },  -- lualine segment ro refresh.
        })
    end
EOF
    else
        let &stl=&stl
    endif
endfunction
function! s:ContextWindow.__echoTipsIfEnabled()
    if s:enable_echo_tips == 1
        echo vmenu#itemTips()
    endif
endfunction
function! s:ContextWindow.getFocusedItemTips()
    return self.getCurItem().tip
endfunction
function! s:ContextWindow.focusBottom()
    call self.__focusFirstMatch(reverse(range(self.__componentLength)))
endfunction
" idx: the index in the item list.
" note: the item at the index must be exist
function! s:ContextWindow.canBeFocused(idx)
    return self.contextItemList[a:idx].isSep == 0 && self.contextItemList[a:idx].isInactive(self.__editorStatusSupplier()) == 0
endfunction

function! s:ContextWindow.enter()
    if !self.canBeFocused(self.__curItemIndex)
        call self.__errConsumer("vmenu: current item is not executable!")
        return
    endif

    if -1 == self.__curItemIndex
        call self.__errConsumer("vmenu: there is no focused item!")
        return
    endif

    let subItemList = self.contextItemList[self.__curItemIndex].subItemList
    if (!subItemList->empty())
        let subWindow = self.__expand()
        call subWindow.__focusFirstMatch(range(subWindow.__componentLength))
    else
        call self.__execute()
    endif
endfunction
function! s:ContextWindow.__expand()
    let subItemList = self.contextItemList[self.__curItemIndex].subItemList
    if empty(subItemList)
        return
    endif

    let subContextWindow = s:ContextWindow.builder()
                \.contextItemList(subItemList)
                \.parentVmenuWindow(self)
                \.delay(self.__delayTime)
                \.editorStatusSupplier(self.__editorStatusSupplier)
                \.errConsumer(self.__errConsumer)
                \.build()
    let [x, y] = self.__calcExpandPos(subContextWindow.winWidth)
    let subWindow = subContextWindow.showAt(x, y)
    let self.subVmenuWindow = subWindow
    return subWindow
endfunction
function! s:ContextWindow.__calcExpandPos(winWidth)
    let x = self.x + self.winWidth
    " need minus self.renderStartIdx to correct sub window location when scrollbar is activated
    let y = self.y + self.__curItemIndex - self.renderStartIdx

    " sub window need to be opened on the left in these situations
    " 1) there are insufficient space for sub context window on the right
    " 2) there is already a window opened on the right
    if self.x + self.winWidth + a:winWidth > &columns ||
                \ has_key(self.parentVmenuWindow, 'isInArea') && self.parentVmenuWindow.isInArea(x+1, y+1) == 1 " [x+1, y+1] is top left corner (inclusive) position of expanded window
        let x = self.x - a:winWidth
    endif

    " there are insufficient space on the left, move down one line to prevent obscuring current item
    if x < 0
        let y = y + 1
    endif

    return [x, y]
endfunction
function! s:ContextWindow.__execute()
    call self.close(s:CASCADE_CLOSE)
    call self.__executeCmdField("cmd")
endfunction
function! s:ContextWindow.__executeCmdField(fieldName="cmd")
    let curItem = self.contextItemList[self.__curItemIndex]
    let CmdField = curItem[a:fieldName]
    call s:executeCmd(CmdField, curItem, self.__editorStatusSupplier())
    call s:log(printf("winId: %s, execute cmd: %s", self.winId, CmdField))
endfunction
function! s:ContextWindow.__renderText(start, end)
    return reduce(self.contextItemList[a:start:a:end], { acc, val -> add(acc, val.name) }, [])
endfunction

" offset: the offset of focused item. If offset is -1, no focused item will be rendered
function! s:ContextWindow.__renderHighlight(offset)
    let win = self.quickuiWindow

    let scrollbarHeight = 2 " fixed scrollbar length
    if a:offset >= (self.renderStartIdx + self.winHeight)
        let self.renderStartIdx = a:offset - self.winHeight + 1
        let self.renderEndIdx = a:offset
    endif
    if a:offset < self.renderStartIdx
        let self.renderStartIdx = max([0, a:offset])
        let self.renderEndIdx = max([0, a:offset]) + self.winHeight - 1
    endif

    let needActivateScrollbar = self.winHeight < self.contextItemList->len()
    for index in range(self.renderStartIdx, self.renderEndIdx)
        let curItem = self.contextItemList[index]
        let curItem.syntaxRegionList = []
        let endColumnNr = needActivateScrollbar ? win.opts.w - 1 : win.opts.w

        " inactive item
        if curItem.isInactive(self.__editorStatusSupplier()) == 1
            if curItem.hotKeyPos == -1
                call add(curItem.syntaxRegionList, ["VmenuInactive", 0, endColumnNr])
            else
                call add(curItem.syntaxRegionList, ["VmenuInactive", 0, curItem.hotKeyPos])
                call add(curItem.syntaxRegionList, ["VmenuInactiveHotKey", curItem.hotKeyPos, curItem.hotKeyPos+1])
                call add(curItem.syntaxRegionList, ["VmenuInactive", curItem.hotKeyPos+1, endColumnNr])
            endif

            continue
        endif

        " focused item
        if index == a:offset
            if curItem.hotKeyPos == -1
                call add(curItem.syntaxRegionList, ["VmenuSelect", 0, endColumnNr])
            else
                call add(curItem.syntaxRegionList, ["VmenuSelect", 0, curItem.hotKeyPos])
                call add(curItem.syntaxRegionList, ["VmenuSelectedHotkey", curItem.hotKeyPos, curItem.hotKeyPos+1])
                call add(curItem.syntaxRegionList, ["VmenuSelect", curItem.hotKeyPos+1, endColumnNr])
            endif

            continue
        endif

        " hot key
        if curItem.hotKeyPos != -1
            call add(curItem.syntaxRegionList, ["VmenuHotkey1", curItem.hotKeyPos, curItem.hotKeyPos + 1])
        endif

        " seperator line
        if curItem.isSep == 1
            call add(curItem.syntaxRegionList, ["VmenuSepLine", 0, endColumnNr])
        endif

        " desc
        if curItem.descPos != -1
            call add(curItem.syntaxRegionList, ["VmenuDesc", curItem.descPos, curItem.descPos + curItem.descWidth])
        endif

    endfor

    " refresh content in the scrolling window
    let textList = self.__renderText(self.renderStartIdx, self.renderEndIdx)
    call win.set_text(textList)

    " do render
    let visibleItems = self.contextItemList[self.renderStartIdx:self.renderEndIdx]
    call win.syntax_begin(1)
    for index in range(len(visibleItems))
        for syntax in visibleItems[index].syntaxRegionList
            call win.syntax_region(syntax[0], syntax[1], index, syntax[2], index)
        endfor
    endfor

    call win.syntax_end()
    redraw

    if !empty(self.scrollbarWindow) && self.scrollbarWindow.isOpen == 1
        call self.scrollbarWindow.handleEvent(s:ScrollbarUpdateEvent.new(self.renderStartIdx))
    endif
endfunction

function! s:ContextWindow.__openDocWindowIfAvaliable()
    " close old doc window
    if !empty(self.docWindow) && self.docWindow.isOpen == 1
        call self.docWindow.handleEvent(#{key: "VMENU_CLOSE_DOC_WINDOW"})
    endif

    if !empty(self.getCurItem().doc) && empty(self.getCurItem().subItemList)
        let maxDocHeight = float2nr(self.__editorStatusSupplier().lines * 0.8)
        let docWindow = s:DocWindow.new(self.getCurItem().doc, self, maxDocHeight)
        let [x, y] = self.__calcExpandPos(docWindow.winWidth)
        call docWindow.showAt(x, y)
        let self.docWindow = docWindow
    endif
endfunction


"-------------------------------------------------------------------------------
" class ContextItem
"-------------------------------------------------------------------------------
let s:ContextItem = {}
function! s:ContextItem.new(dict)
    let contextItem                 = {}
    let contextItem.id              = rand(srand())
    let contextItem.path            = ''
    let contextItem.shortKey        = get(a:dict, 'shortKey', '')
    let contextItem.icon            = get(a:dict, 'icon', '')
    let contextItem.cmd             = get(a:dict, 'cmd', '')
    let contextItem.onFocus         = get(a:dict, 'onFocus', '')
    let contextItem.tip             = get(a:dict, 'tip', '')
    let contextItem.name            = get(a:dict, 'name', '')
    let contextItem.originName      = get(a:dict, 'name', '')        " a copy of name. use in s:CallbackItemParam
    let contextItem.hotKey          = get(a:dict, 'hotKey', '')
    let contextItem.hotKeyPos       = get(a:dict, 'hotKeyPos', -1)   " hotkey position
    let contextItem.isVisible  = get(a:dict, 'isVisible')            " EditorStatus class -> 0/1
    let contextItem.isInactive = get(a:dict, 'isInactive')           " EditorStatus class -> 0/1
    let contextItem.subItemList     = get(a:dict, 'subItemList', []) " ContextItem list
    let contextItem.isSep           = get(a:dict, 'isSep', 0)        " is seperator line. 0: false, 1: true
    let contextItem.descPos         = get(a:dict, 'descPos', -1)     " offset of shortKey
    let contextItem.descWidth       = get(a:dict, 'descWidth', 0)    " length of shortKey
    let contextItem.stretchingIndex = strwidth(contextItem.name)   " the index for stretching (contextItem.name[stretchingIndex-1] is the last char of item name). used for minWidth
    let contextItem.syntaxRegionList       = [] " [[highlight, start (inclusive), end (exclusive)]]
    let contextItem.itemVersion     = get(a:dict, 'itemVersion', 0)  " context item version. see: g:VMENU#ITEM_VERSION
    let contextItem.group           = get(a:dict, 'group', '')  " group name of current item
    let contextItem.doc             = get(a:dict, 'doc', [])  " document text of current item
    return contextItem
endfunction

function! s:initItemPathRecursively(contextItem, parentPath, separatorChar=s:ITEM_PATH_SEP)
    if '' == a:parentPath
        let a:contextItem.path = a:contextItem.name
    else
        let a:contextItem.path = a:parentPath .. a:separatorChar .. a:contextItem.name
    endif
    for item in a:contextItem.subItemList
        call s:initItemPathRecursively(item, a:contextItem.path)
    endfor
endfunction

"-------------------------------------------------------------------------------
" class TopMenuItem
"-------------------------------------------------------------------------------
let s:TopMenuItem = {}
function! s:TopMenuItem.new(name, hotKey, hotKeyPos, contextItemList)
    let topMenuItem = deepcopy(s:TopMenuItem, 1)
    let topMenuItem.name = a:name
    let topMenuItem.path = a:name
    let topMenuItem.hotKeyPos = a:hotKeyPos
    let topMenuItem.hotKey = a:hotKey
    let topMenuItem.contextItemList = deepcopy(a:contextItemList, 1)
    return topMenuItem
endfunction
function! s:TopMenuItem.appendTopMenuItems(contextItemList)
    call extend(self.subItemList, deepcopy(a:contextItemList, 1))
endfunction

"-------------------------------------------------------------------------------
" class TopMenuWindowBuilder extends VmenuWindowBuilder
"-------------------------------------------------------------------------------
let s:TopMenuWindowBuilder = {}
function s:TopMenuWindowBuilder.new()
    let topMenuWindowBuilder = s:VmenuWindowBuilder.new()
    call extend(topMenuWindowBuilder, deepcopy(s:TopMenuWindowBuilder, 1), "force")
    let topMenuWindowBuilder.__topMenuItemList = []
    let topMenuWindowBuilder.__goPreviousKey = 'h'
    let topMenuWindowBuilder.__goNextKey = 'l'
    let topMenuWindowBuilder.__closeKey = "\<ESC>"
    let topMenuWindowBuilder.__confirmKey = "\<CR>"
    return topMenuWindowBuilder
endfunction
function! s:TopMenuWindowBuilder.topMenuItemList(topMenuItemList)
    let self.__topMenuItemList = a:topMenuItemList
    return self
endfunction
function! s:TopMenuWindowBuilder.build()
    return s:TopMenuWindow.new(self)
endfunction

"-------------------------------------------------------------------------------
" class TopMenuWindow extends VmenuWindow
"-------------------------------------------------------------------------------
let s:TopMenuWindow = {}
function! s:TopMenuWindow.builder()
    return s:TopMenuWindowBuilder.new()
endfunction
function! s:TopMenuWindow.new(topMenuWindowBuilder)
    let topMenuWindow = s:VmenuWindow.new()
    call extend(topMenuWindow, deepcopy(s:TopMenuWindow, 1), "force")
    let topMenuWindow.topMenuItemList = a:topMenuWindowBuilder.__topMenuItemList
    let topMenuWindow.topMenuItemList = s:ItemParser.__addPaddingInTopMenu(topMenuWindow.topMenuItemList, '  ')
    let s:VmenuWindow.__allTopMenuItemList = topMenuWindow.topMenuItemList
    let topMenuWindow.quickuiWindow = quickui#window#new()
    let topMenuWindow.winId = rand(srand())
    let topMenuWindow.hotKeyList = []
    let topMenuWindow.winWidth = &columns
    let topMenuWindow.__componentLength = topMenuWindow.topMenuItemList->len()
    for i in range(len(topMenuWindow.topMenuItemList))
        if topMenuWindow.topMenuItemList[i].hotKey != ''
            call add(topMenuWindow.hotKeyList, s:HotKey.new(topMenuWindow.topMenuItemList[i].hotKey->tolower(), i))
        endif
    endfor

    let topMenuWindow.__curItemIndex = 0
    let topMenuWindow.__padding = 2 " spaces added on the left and right side for every item
    let topMenuWindow.__delayTime = a:topMenuWindowBuilder.__delayTime
    let topMenuWindow.__errConsumer = a:topMenuWindowBuilder.__errConsumer
    let topMenuWindow.isOpen = 0
    call s:log(printf("new TopMenuWindow created, winId: %s", topMenuWindow.winId))

    let actionMap = {}
    let actionMap[a:topMenuWindowBuilder.__closeKey]      = { event -> topMenuWindow.close(s:CLOSE_SELF_ONLY, a:topMenuWindowBuilder.__closeKey) }
    let actionMap[a:topMenuWindowBuilder.__goNextKey]     = { event -> topMenuWindow.focusNext() }
    let actionMap[a:topMenuWindowBuilder.__goPreviousKey] = { event -> topMenuWindow.focusPrev() }
    let actionMap[a:topMenuWindowBuilder.__goBottomKey]   = { event -> topMenuWindow.focusBottom() }
    let actionMap[a:topMenuWindowBuilder.__confirmKey]    = { event -> topMenuWindow.enter() }
    let actionMap["\<LeftMouse>"]                         = { event -> topMenuWindow.executeByLeftMouse(event) }
    let actionMap["VMENU_MOUSE_HOVER"]                    = { event -> topMenuWindow.__onMouseHover(event) }
    let actionMap["VMENU_SUB_MENU_CLOSE"]                 = { event -> topMenuWindow.__onSubMenuClose(event.closeCode, event.event) }
    let actionMap["VMENU_RECURSIVE_CLOSE"]                = { event -> topMenuWindow.close(s:RECURSIVE_CLOSE) }
    for hotKey in topMenuWindow.hotKeyList
        let actionMap[hotKey['keyChar']]                  = { event -> topMenuWindow.executeByHotKey(event.key) }
    endfor

    let topMenuWindow.__actionMap = actionMap
    return topMenuWindow
endfunction
function! s:TopMenuWindow.getCurItem()
    return self.topMenuItemList[self.__curItemIndex]
endfunction
function! s:TopMenuWindow.show()
    let opts = {}
    let text = self.__renderText()
    let opts.h = 1
    let opts.w = self.winWidth
    let opts.color = "VmenuBg"
    let opts.y = 0
    let opts.x = 0

    let win = self.quickuiWindow
    call win.open(text, opts)
    let self.x = opts.x
    let self.y = opts.y

    redraw
    let self.isOpen = 1
    call s:VMenuManager.setFocusedWindow(self)
    call self.focusItemByIndex(self.__curItemIndex)
    call s:log(printf("TopMenuWindow opened at x:%s, y:%s, winId: %s", opts.x, opts.y, self.winId))
    return self
endfunction
function! s:TopMenuWindow.focusItemByIndex(index)
    let self.__curItemIndex = a:index
    call self.__renderHighlight(self.__curItemIndex)
    redraw
endfunction
function! s:TopMenuWindow.enter()
    let subWindow = self.__expand()
    if !empty(subWindow)
        call subWindow.__focusFirstMatch(range(subWindow.__componentLength))
    endif
endfunction
function! s:TopMenuWindow.__expand()
    let subItemList = self.topMenuItemList[self.__curItemIndex].contextItemList
    if subItemList->empty()
        return
    endif

    let x = self.__getStartColumnNrByIndex(self.__curItemIndex)
    let y = 1
    try
        let subContextWindow = s:ContextWindow.builder()
                    \.contextItemList(subItemList)
                    \.parentVmenuWindow(self)
                    \.build()
                    \.showAt(x, 1)
    catch "NoVisibleItemException"
        return
    endtry
    let self.subVmenuWindow = subContextWindow
    call self.subVmenuWindow.__renderHighlight(-1)
    return subContextWindow
endfunction
" calculate start column to render focused top menu item
function! s:TopMenuWindow.__getStartColumnNrByIndex(index)
    return a:index == 0 ? 0
                \: reduce(self.topMenuItemList[:a:index-1], { acc, val -> acc + strwidth(val.name) }, 0)
endfunction
function! s:TopMenuWindow.__renderText()
    return reduce(self.topMenuItemList, { acc, val -> acc .. val.name }, '')
endfunction
" rendering focused line, hot key, inactive line
function! s:TopMenuWindow.__renderHighlight(offset)
    let win = self.quickuiWindow

    call win.syntax_begin(1)
    for index in range(len(self.topMenuItemList))
        " hot key
        if self.topMenuItemList[index].hotKeyPos == -1
            continue
        endif
        let startX = self.__getStartColumnNrByIndex(index) + self.topMenuItemList[index].hotKeyPos
        call win.syntax_region("VmenuHotkey1", startX, 0, startX + 1, 0)
    endfor

    let syntaxRegionList = []
    let item = self.topMenuItemList[a:offset]
    if self.topMenuItemList[a:offset].hotKeyPos == -1
        let startX = self.__getStartColumnNrByIndex(self.__curItemIndex)
        call add(syntaxRegionList, ['VmenuSelect', startX, startX + strwidth(self.getCurItem().name)])
    else
        let startX = self.__getStartColumnNrByIndex(self.__curItemIndex) " start position in whole top menu window
        let endX = startX + item.hotKeyPos
        call add(syntaxRegionList, ['VmenuSelect', startX, endX])
        call add(syntaxRegionList, ["VmenuSelectedHotkey", endX, endX+1])
        call add(syntaxRegionList, ["VmenuSelect", endX+1, startX+strwidth(item.name)])
    endif
    let item.syntaxRegionList = deepcopy(syntaxRegionList, 1)
    for syntax in syntaxRegionList
        call win.syntax_region(syntax[0], syntax[1], 0, syntax[2], 0)
    endfor
    call win.syntax_end()
endfunction

function! s:TopMenuWindow.getItemIndexOnPos(mousePos)
    let clickedPos = #{x: a:mousePos.screencol, y: a:mousePos.screenrow}
    let topLeftCorner = s:VMenuManager.calcTopLeftPos(self)
    call s:log("clickedPos:" .. string(clickedPos))
    call s:log("topLeftCorner:" .. string(topLeftCorner))
    if clickedPos.y != 1
        return -1
    endif

    for i in range(s:VMenuManager.__allTopMenuItemList->len())
        if i+1 >= s:VMenuManager.__allTopMenuItemList->len()
            return i
        endif

        " the x of top menu starts from 1, so the result of __getStartColumnNrByIndex needs a offset of 1
        let startCol = self.__getStartColumnNrByIndex(i) + 1
        let endCol = self.__getStartColumnNrByIndex(i+1) + 1
        if startCol <= clickedPos.x && clickedPos.x < endCol
            return i
        endif
    endfor

    return -1
endfunction

"-------------------------------------------------------------------------------
" class DocWindow extends EventHandler implements dumpContent
"-------------------------------------------------------------------------------
let s:DocWindow = {}
function! s:DocWindow.new(textList, parentVmenuWindow, maxHeight)
    let docWindow = s:EventHandler.new()
    call extend(docWindow, deepcopy(s:DocWindow, 1), "force")
    let docWindow.isOpen = 0
    let docWindow.textList = a:textList
    let docWindow.highlight = []
    let docWindow.__startIdx = 0
    let docWindow.parentVmenuWindow = a:parentVmenuWindow
    let docWindow.winId = rand(srand())
    let docWindow.scrollbarWindow = {}

    let actionMap = {}
    let scrollDownKey = s:doc_window_scroll_down_key
    let scrollUpKey = s:doc_window_scroll_up_key
    let actionMap[scrollDownKey]            = { event -> docWindow.scrollDown() }
    let actionMap[scrollUpKey]              = { event -> docWindow.scrollUp() }
    let actionMap["VMENU_CLOSE_DOC_WINDOW"] = { event -> docWindow.close() }
    let docWindow.__actionMap = actionMap

    " visible window width. max width in text list
    let docWindow.winWidth = reduce(a:textList, { acc, val -> max([acc, strwidth(val)]) }, 0)
    let docWindow.maxTextLen = docWindow.winWidth

    " visible window height
    let docWindow.winHeight = min([len(a:textList), a:maxHeight])
    return docWindow
endfunction
function! s:DocWindow.showAt(x, y)
    let win = quickui#window#new()
    let displayedTextList = self.textList[self.__startIdx:self.__startIdx+self.winHeight-1]
    if len(self.textList) > self.winHeight
        let self.winWidth = self.winWidth + 1   " plus one for scrollbar
    endif

    let opts = {}
    let opts.w = self.winWidth
    let opts.h = self.winHeight
    let opts.padding = [0, 1, 0, 1]
    let opts.x = a:x
    let opts.y = a:y
    let opts.color = "VmenuDocWindow"
    if s:enable_markdown_syntax_in_doc_window == 1
        let opts.syntax = "markdown"
    endif

    call win.open(displayedTextList, opts)

    let self.__window = win
    let self.isOpen = 1
    let self.x = win.x " column number
    let self.y = win.y " line number

    call self.__window.show(1)

    redraw
    if self.textList->len() > self.winHeight    " need to add scrollbar
        let scrollbarWidow = s:ScrollbarWindow.new(self.winHeight, self.textList->len(), 2)
        call scrollbarWidow.showAt(self.x+self.maxTextLen, self.y)
        let self.scrollbarWindow = scrollbarWidow
    endif

    call s:VMenuManager.setFocusedWindow(self)
    redraw
endfunction
function! s:DocWindow.dispatch(inputEvent)
    if has_key(self.__actionMap, a:inputEvent.key)
        call get(self.__actionMap, a:inputEvent.key, { -> ''})(a:inputEvent)
    else
        call self.parentVmenuWindow.handleEvent(a:inputEvent)
    endif
endfunction
function! s:DocWindow.dumpContent()
    return #{textList: self.__window.text, highlight: self.highlight}
endfunction
function! s:DocWindow.scrollDown()
    " reach the bottom. do nothing
    if self.__startIdx + self.winHeight >= len(self.textList)
        return
    endif

    let self.__startIdx = self.__startIdx + 1
    let renderContent = self.textList[self.__startIdx:self.__startIdx+self.winHeight-1]
    call self.__window.set_text(renderContent)
    redraw
    if !empty(self.scrollbarWindow) && self.scrollbarWindow.isOpen == 1
        call self.scrollbarWindow.handleEvent(s:ScrollbarUpdateEvent.new(self.__startIdx))
    endif
endfunction
function! s:DocWindow.scrollUp()
    " reach the top. do nothing
    if self.__startIdx == 0
        return
    endif

    let self.__startIdx = self.__startIdx - 1
    let renderContent = self.textList[self.__startIdx:self.__startIdx+self.winHeight-1]

    call self.__window.set_text(renderContent)
    redraw
    if !empty(self.scrollbarWindow) && self.scrollbarWindow.isOpen == 1
        call self.scrollbarWindow.handleEvent(s:ScrollbarUpdateEvent.new(self.__startIdx))
    endif
endfunction
function! s:DocWindow.close()
    call self.__window.close()
    if !empty(self.scrollbarWindow)
        call self.scrollbarWindow.handleEvent(#{key: "SCROLLBAR_CLOSE"})
    endif
    let self.isOpen = 0
endfunction

"-------------------------------------------------------------------------------
" class ScrollbarWindow extends EventHandler implements dumpContent
"-------------------------------------------------------------------------------
let s:ScrollbarWindow = {}
function! s:ScrollbarWindow.new(winHeight, total, thumbHeight=2, barWinColor="VmenuDocWindow", thumbColor="VmenuDocWindowScrollbar")
    let scrollbarWindow = s:EventHandler.new()
    call extend(scrollbarWindow, deepcopy(s:ScrollbarWindow, 1), "force")
    let scrollbarWindow.winHeight = a:winHeight
    let scrollbarWindow.thumbHeight = a:thumbHeight
    let scrollbarWindow.total = a:total
    let scrollbarWindow.winId = rand(srand())
    let scrollbarWindow.winWidth = 1
    let scrollbarWindow.winHeight = a:winHeight
    let scrollbarWindow.isOpen = 0
    let scrollbarWindow.highlight = []
    let scrollbarWindow.thumbColor = a:thumbColor
    let scrollbarWindow.barWinColor = a:barWinColor

    let actionMap = {}
    let actionMap["SCROLLBAR_UPDATE"] =
                \ { scrollbarUpdateEvent -> scrollbarWindow.update(scrollbarUpdateEvent.scrolledCnt) }
    let actionMap["SCROLLBAR_CLOSE"] =
                \ { event -> scrollbarWindow.close() }
    let scrollbarWindow.__actionMap = actionMap


    call s:log(printf("scrollbar window created, winId: %s", scrollbarWindow.winId))
    return scrollbarWindow
endfunction
function! s:ScrollbarWindow.showAt(x, y)
    let win = quickui#window#new()
    let renderContent = self.__calcRenderContent(0)
    let displayedTextList = renderContent.textList

    let opts = {}
    let opts.w = self.winWidth
    let opts.h = self.winHeight
    let opts.padding = [0, 1, 0, 1]
    let opts.x = a:x
    let opts.y = a:y
    let opts.color = self.barWinColor

    call win.open(displayedTextList, opts)

    let self.__window = win
    let self.isOpen = 1
    let self.x = win.x " column number
    let self.y = win.y " line number
    let self.highlight = renderContent.highlight

    call self.__window.show(1)

    call win.syntax_begin(1)
    for syntax in renderContent.highlight
        call win.syntax_region(syntax.highlight, syntax.x1, syntax.y1, syntax.x2, syntax.y2)
    endfor

    call win.syntax_end()
    redraw
    return self
endfunction
function! s:ScrollbarWindow.__calcRenderContent(scrolled)
    let textList = mapnew(range(self.winHeight), '" "')
    let highlight = []
    let scrollbarOffset = (self.winHeight - self.thumbHeight) * a:scrolled / (self.total - self.winHeight)
    for i in range(self.thumbHeight)
        let textList[scrollbarOffset+i] = '█'
        call add(highlight, #{highlight: self.thumbColor, x1: 0, y1: scrollbarOffset+i, x2: 1, y2: scrollbarOffset+i})
    endfor
    return #{textList: textList, highlight: highlight}
endfunction
function! s:ScrollbarWindow.close()
    call self.__window.close()
    let self.isOpen = 0
endfunction
function! s:ScrollbarWindow.update(scrolledCnt)
    let renderContent = self.__calcRenderContent(a:scrolledCnt)
    let displayedTextList = renderContent.textList
    call self.__window.set_text(displayedTextList)
    let self.highlight = renderContent.highlight

    call self.__window.syntax_begin(1)
    for syntax in renderContent.highlight
        call self.__window.syntax_region(syntax.highlight, syntax.x1, syntax.y1, syntax.x2, syntax.y2)
    endfor

    call self.__window.syntax_end()
    redraw
endfunction
function! s:ScrollbarWindow.dumpContent()
    return #{textList: self.__window.text, highlight: self.highlight}
endfunction

"-------------------------------------------------------------------------------
" class EditorStatus
"-------------------------------------------------------------------------------
let s:EditorStatus = {}
function! s:getEditorStatus(curMode="n")
    let editorStatus = {}
    let editorStatus.currentMode = a:curMode
    let editorStatus.currentFileType = &ft
    " get selected text will move the cursor to the last visual area, so only get selected text in visual mode.
    let editorStatus.selectedText = a:curMode[0:1] ==? "v" ? s:getSelectedText() : ""
    let editorStatus.lines = &lines   " Number of lines of the Vim window.
    return editorStatus
endfunction


"-------------------------------------------------------------------------------
" class VMenuManager
"-------------------------------------------------------------------------------
let s:VMenuManager = {}
let s:VMenuManager.__allTopMenuItemList = []
let s:VMenuManager.__focusedWindow = {}
let s:VMenuManager.__keepGettingInput = 0
let s:VMenuManager.parsedContextItemList = []
let s:VMenuManager.LastEditorStatus = {}      " save the editor status when calling vmenu#queryItems. this will be used in vmenu#executeItemById
let s:VMenuManager.lastQueryableItems = []    " save the last queryable item list when calling vmenu#queryItems. this will be used in vmenu#executeItemById
function! s:VMenuManager.parseContextItem(userItemList, itemVersion=g:VMENU#ITEM_VERSION.QUICKUI)
    let ItemParser = function(s:ItemParser.parseQuickuiItem, [])
    if a:itemVersion == g:VMENU#ITEM_VERSION.VMENU
        let ItemParser = function(s:ItemParser.parseVMenuItem, [])
    endif
    let contextItemList = reduce(a:userItemList, { acc, val -> add(acc, ItemParser(val)) }, [])
    call foreach(contextItemList, { i, v -> s:initItemPathRecursively(v, '') })

    return deepcopy(contextItemList, 1)
endfunction
function! s:VMenuManager.initTopMenuItems(name, userItemList)
    let topItem = s:ItemParser.parseQuickuiItem([a:name])
    if indexof(self.__allTopMenuItemList, {i, v -> v.name == topItem.name}) != -1
        call s:log(printf("top menu: %s already installed, ignore.", a:name))
        return
    endif

    let subItemList = self.parseUserDefinedItemList(a:userItemList)
    call foreach(subItemList, { i, v -> s:initItemPathRecursively(v, topItem.name) })
    call s:VMenuManager.saveParsedContextItemList(subItemList)

    let topMenuItem = s:TopMenuItem.new(topItem.name, topItem.hotKey,
                \ topItem.hotKeyPos, subItemList)
    call add(s:VMenuManager.__allTopMenuItemList, topMenuItem)
    return topMenuItem
endfunction
function! s:VMenuManager.parseUserDefinedItemList(userItemList)
    let IsParsedVmenuItems = { val -> type(val) == v:t_dict && has_key(val, 'itemVersion') }

    let itemList = []
    " the userItemList may mixed with vim-qucikui items and parsed vmenu items.
    " for the latter, just use directely
    for item in a:userItemList
        if IsParsedVmenuItems(item)
            call add(itemList, deepcopy(item, 1))
        else
            call add(itemList, s:ItemParser.parseQuickuiItem(item))
        endif
    endfor
    return itemList
endfunction

function! s:VMenuManager.startListening()
    if s:enable_mouse_hover
        call self.mouseHoverEnabledListen()
    else
        call self.defaultListen()
    endif
endfunction

function! s:VMenuManager.defaultListen()
    let self.__keepGettingInput = 1
    while self.__keepGettingInput
        let code = getchar()

        let ch = (type(code) == v:t_number)? nr2char(code) : code

        let event = {}
        if ch == "\<LeftMouse>"
            let event = s:MouseClickEvent.new(getmousepos())
        else
            let event = s:KeyStrokeEvent.new(ch)
        endif

        call self.__focusedWindow.handleEvent(event)
    endwhile
endfunction

function! s:VMenuManager.mouseHoverEnabledListen()
    let self.__keepGettingInput = 1
    while self.__keepGettingInput
        if getchar(1) == 0
            sleep 40m
            continue
        endif

        let code = getchar(0)

        let ch = (type(code) == v:t_number)? nr2char(code) : code

        let event = {}
        if ch == "\<LeftMouse>"
            let event = s:MouseClickEvent.new(getmousepos())
        elseif code == 0
            let event = s:MouseHoverEvent.new(getmousepos())
        else
            let event = s:KeyStrokeEvent.new(ch)
        endif

        call self.__focusedWindow.handleEvent(event)
    endwhile
endfunction

function! s:VMenuManager.stopListen()
    let self.__keepGettingInput = 0
endfunction

 " focused context window will receive and handle user input
function! s:VMenuManager.setFocusedWindow(contextWindow)
    let self.__focusedWindow = a:contextWindow
    call s:log("set focused window: " .. a:contextWindow.winId)
endfunction

" top left position (inclusive) of vmenu window
function! s:VMenuManager.calcTopLeftPos(vmenuWindow)
    return #{x: a:vmenuWindow.x+1, y: a:vmenuWindow.y+1}
endfunction

function! s:VMenuManager.saveParsedContextItemList(items)
    call extend(s:VMenuManager.parsedContextItemList, deepcopy(a:items, 1))
endfunction


function! s:getSelectedText()
    let origin = getreg('z')
    call execute('norm gv"zy')
    let selectedText = getreg('z')
    call setreg('z', origin)
    return selectedText
endfunction


"-------------------------------------------------------------------------------
" class ItemParser
"-------------------------------------------------------------------------------
let s:ItemParser = {}
function! s:ItemParser.parseVMenuItem(userItem)
    let quickuiItem = {}
    let quickuiItem = quickui#utils#item_parse([get(a:userItem, 'name', '')])
    let name      = quickuiItem.text
    let hotKeyPos = get(quickuiItem, 'key_pos', '')
    let hotKey    = get(quickuiItem, 'key_char', '')
    let isSep     = get(a:userItem, 'isSep', '')
    let Cmd       = get(a:userItem, 'cmd', '')
    let OnFocus   = get(a:userItem, 'onFocus', '')
    let tip       = get(a:userItem, 'tip', '')
    let icon      = get(a:userItem, 'icon', '')
    let shortKey  = get(quickuiItem, 'desc', '')
    let descPos   = -1    " will be calculated when context window created
    let descWidth = get(quickuiItem, 'desc_width', 0)
    let group     = get(a:userItem, 'group', '')
    let doc       = get(a:userItem, 'doc', [])
    let subItemList = []
    if (has_key(a:userItem, 'subItemList'))
        for item in get(a:userItem, 'subItemList')
            call add(subItemList, s:ItemParser.parseVMenuItem(item))
        endfor
    endif
    let VisiblePredicate = { -> 1 } " true by default
    if has_key(a:userItem, 'show-mode')
        let VisiblePredicate = s:createModePredicate(get(a:userItem, 'show-mode'))
    endif
    if has_key(a:userItem, 'show-ft')
        let VisiblePredicate = s:createFileTypePredicate(get(a:userItem, 'show-ft'))
    endif
    " a custom predicate
    if has_key(a:userItem, 'show-if')
        let VisiblePredicate = get(a:userItem, 'show-if')
    endif

    let DeactivePredicate = { -> 0 }    " false by default
    if has_key(a:userItem, 'deactive-mode')
        let DeactivePredicate = s:createModePredicate(get(a:userItem, 'deactive-mode'))
    endif
    if has_key(a:userItem, 'deactive-ft')
        let DeactivePredicate = s:createFileTypePredicate(get(a:userItem, 'deactive-ft'))
    endif
    if has_key(a:userItem, 'deactive-if')
        let DeactivePredicate = get(a:userItem, 'deactive-if')
    endif

    return s:ContextItem.new(
                \#{name: name,
                \icon: icon,
                \cmd: Cmd,
                \tip: tip,
                \shortKey: shortKey,
                \hotKey: hotKey,
                \hotKeyPos: hotKeyPos,
                \isVisible: VisiblePredicate,
                \isInactive: DeactivePredicate,
                \subItemList: subItemList,
                \isSep: isSep,
                \itemVersion: g:VMENU#ITEM_VERSION.VMENU,
                \descPos: descPos,
                \descWidth: descWidth,
                \group: group,
                \onFocus: OnFocus,
                \doc: doc,
                \})
endfunction
function! s:ItemParser.parseQuickuiItem(quickuiItem)
    let workingQuickuiItem = []
    if type(a:quickuiItem) == v:t_dict
        let workingQuickuiItem = [get(a:quickuiItem, 'text', ''), get(a:quickuiItem, 'cmd', ''), get(a:quickuiItem, 'help', '')]
    else
        let workingQuickuiItem = a:quickuiItem
    endif
    let quickuiItemObj = quickui#utils#item_parse(workingQuickuiItem)
    let icon      = type(a:quickuiItem) == v:t_dict ? get(a:quickuiItem, 'icon', '') : ''
    let name      = get(quickuiItemObj, 'text', '')
    let cmd       = get(quickuiItemObj, 'cmd', '')
    let tip       = get(quickuiItemObj, 'help', '')
    let shortKey  = get(quickuiItemObj, 'desc', '')
    let hotKeyPos = get(quickuiItemObj, 'key_pos', -1)  " will be calculated when context window created
    let hotKey    = get(quickuiItemObj, 'key_char', '')
    let isSep     = get(quickuiItemObj, 'is_sep', 0)
    let descPos = -1    " will be calculated when context window created
    let descWidth = get(quickuiItemObj, 'desc_width', 0)
    let subItemList = []

    " extract second menu. leo-fp/vim-quickui feature
    if match(cmd, 'quickui#context#expand') != -1
        let callId = rand(srand())
        let extractCmd = substitute(cmd, 'quickui#context#expand(', 's:extractSubMenuOfExpand(' .. callId .. " ,", '')
        call execute(extractCmd)

        for item in s:secondMenuMap[callId]
            call add(subItemList, s:ItemParser.parseQuickuiItem(item))
        endfor

        " cmd is useless if there are second menu
        let cmd = ''
    endif
    let VisiblePredicate = { -> 1 }
    let DeactivePredicate = { -> 0 }

    return s:ContextItem.new(
                \#{name: name,
                \icon: icon,
                \cmd: cmd,
                \tip: tip,
                \shortKey: shortKey,
                \hotKey: hotKey,
                \hotKeyPos: hotKeyPos,
                \isVisible: VisiblePredicate,
                \isInactive: DeactivePredicate,
                \subItemList: subItemList,
                \descPos: descPos,
                \descWidth: descWidth,
                \isSep: isSep,
                \itemVersion: g:VMENU#ITEM_VERSION.QUICKUI},
                \)
endfunction

function! s:ItemParser.__fillNameToSameLength(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    let maxNameLen = reduce(workingContextItemList, { acc, val -> max([acc, strwidth(val.name)]) }, 0)
    for contextItem in workingContextItemList
        if strwidth(contextItem.name) < maxNameLen
            let contextItem.name = contextItem.name .. repeat(' ', maxNameLen - strwidth(contextItem.name))
        endif
        "let contextItem.stretchingIndex = strwidth(contextItem.name)
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__concatenateShortKey(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    for contextItem in workingContextItemList
        let left = contextItem.name .. (empty(contextItem.shortKey) ? '' : "    ")
        let contextItem.name = left .. contextItem.shortKey
        let contextItem.descPos = strwidth(contextItem.shortKey) > 0 ?
                    \ strwidth(left) : -1 " adjust desc pos
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__addPaddingInContextMenu(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    for contextItem in workingContextItemList
        let paddingLeft = '  '
        let contextItem.name = paddingLeft .. contextItem.name .. '  '
        let contextItem.descPos = strwidth(contextItem.shortKey) > 0 ?
                    \ contextItem.descPos + strwidth(paddingLeft) : -1 " adjust desc pos
        let contextItem.stretchingIndex = contextItem.stretchingIndex + strwidth(paddingLeft) " adjust stretching index
        let contextItem.hotKeyPos = contextItem.hotKeyPos == -1 ? -1 : contextItem.hotKeyPos + 2
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__addPaddingInTopMenu(topMenuItemList, paddingStr)
    let workingTopMenuList = deepcopy(a:topMenuItemList, 1)
    for topMenuItem in workingTopMenuList
        let padding = a:paddingStr
        let topMenuItem.name = padding .. topMenuItem.name .. padding
        let topMenuItem.hotKeyPos = topMenuItem.hotKeyPos != -1 ?
                    \ topMenuItem.hotKeyPos + strwidth(padding) : -1 " adjust desc pos
    endfor
    return workingTopMenuList
endfunction
function! s:ItemParser.__addIcon(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    let maxIconLen = reduce(workingContextItemList, { acc, val -> max([acc, strwidth(val.icon)]) }, 0)
    for contextItem in workingContextItemList
        let iconPart = contextItem.icon .. repeat(' ', maxIconLen-strwidth(contextItem.icon)) .. ' '
        let contextItem.name = iconPart .. contextItem.name
        let contextItem.descPos = contextItem.descPos + strwidth(iconPart)  " adjust desc pos
        let contextItem.hotKeyPos = contextItem.hotKeyPos == -1 ? -1 : contextItem.hotKeyPos + strwidth(iconPart)
        let contextItem.stretchingIndex = contextItem.stretchingIndex == -1 ? -1 : contextItem.stretchingIndex + strwidth(iconPart)
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__stretchingIfNeed(contextItemList, minWidth)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    for contextItem in workingContextItemList
        let stretchingPart = repeat(' ', max([0, a:minWidth - strwidth(contextItem.name)]))
        let contextItem.name = strcharpart(contextItem.name, 0, contextItem.stretchingIndex)
                    \ .. stretchingPart
                    \ .. strcharpart(contextItem.name, contextItem.stretchingIndex, strwidth(contextItem.name))
        let contextItem.descPos = strwidth(contextItem.shortKey) > 0 ?
                    \ contextItem.descPos + strwidth(stretchingPart) : -1 " adjust desc pos
        let contextItem.stretchingIndex = contextItem.stretchingIndex + strwidth(stretchingPart) " adjust stretching index
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__renderSeparatorLine(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    if a:contextItemList->empty()
        return workingContextItemList
    endif

    let width = strwidth(a:contextItemList[0].name)
    for contextItem in workingContextItemList
        if (contextItem.isSep == 1)
            let contextItem.name = ' ' .. repeat('—', max([1, width-2])) .. ' '
        endif
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__addSurroundedSeparatorLine(contextItemList)
    " place items with same group next to each other
    let sortedItemList = []
    let groupSet = []
    for item in a:contextItemList
        " do not handle default group
        if item.group == ''
            continue
        endif

        let idx = indexof(groupSet, {i, v -> v.groupName == item.group})
        if idx == -1
            call add(groupSet, #{groupName: item.group, items: [item]})
        else
            call add(groupSet[idx].items, item)
        endif
    endfor

    for item in a:contextItemList
        if item.group == ''
            call add(sortedItemList, deepcopy(item, 1))
        else
            let idx = indexof(groupSet, {i, v -> v.groupName == item.group})
            if idx != -1
                call extend(sortedItemList, groupSet[idx].items)
                call remove(groupSet, idx)
            endif
        endif
    endfor

    let workingContextItemList = []
    for idx in range(sortedItemList->len())
        if (sortedItemList[idx].group != '')
            if idx == 0 || sortedItemList[idx-1].isSep == 1
                        \ || sortedItemList[idx-1].group == sortedItemList[idx].group
                        \ || workingContextItemList[workingContextItemList->len()-1].isSep == 1
            else
                call add(workingContextItemList, self.parseVMenuItem(#{isSep: 1}))
            endif

            call add(workingContextItemList, deepcopy(sortedItemList[idx], 1))

            if idx == sortedItemList->len()-1 || sortedItemList[idx+1].isSep == 1
                        \ || sortedItemList[idx+1].group == sortedItemList[idx].group
            else
                call add(workingContextItemList, self.parseVMenuItem(#{isSep: 1}))
            endif
        else
            call add(workingContextItemList, deepcopy(sortedItemList[idx], 1))
        endif
    endfor

    return workingContextItemList
endfunction

let s:secondMenuMap = {}
function! s:extractSubMenuOfExpand(callId, quickuiItem)
    let s:secondMenuMap = {}
    let s:secondMenuMap[a:callId] = deepcopy(a:quickuiItem)
endfunction

function! s:createModePredicate(modes)
    return { editorStatus -> index(a:modes, editorStatus['currentMode']) != -1}
endfunction

function! s:createFileTypePredicate(fileTypes)
    return { editorStatus -> index(a:fileTypes, editorStatus['currentFileType']) != -1}
endfunction


"-------------------------------------------------------------------------------
" API
"-------------------------------------------------------------------------------
" content: context item list
" opts.curMode: the mode string when calling this function.
function! vmenu#openContextWindow(content, opts)
    let contextWindowBuilder = s:ContextWindow.builder()
                \.contextItemList(s:VMenuManager.parseUserDefinedItemList(a:content))
    if get(a:opts, 'curMode', '') != ''
        let contextWindowBuilder = contextWindowBuilder.editorStatusSupplier({ -> s:getEditorStatus(a:opts.curMode) })
    endif

    try
        call contextWindowBuilder.build()
                    \.showAtCursor()
        call s:VMenuManager.startListening()
    catch "NoVisibleItemException"
        return
    endtry
endfunction
" userItemList: quickui context menu or vmenu context menu
" return parsed context item list
function! vmenu#parse_context(userItemList, itemVersion=g:VMENU#ITEM_VERSION.QUICKUI)
    return s:VMenuManager.parseContextItem(a:userItemList, a:itemVersion)
endfunction
function! vmenu#installTopMenu(name, userTopMenu)
    call s:VMenuManager.initTopMenuItems(a:name ,a:userTopMenu)
endfunction
function! vmenu#appendTopMenu(name, vmenuItems)
    let topItem = s:ItemParser.parseQuickuiItem([a:name])
    let idx = indexof(s:VMenuManager.__allTopMenuItemList, {i, v -> v.name == topItem.name})
    let dropMenu = s:VMenuManager.parseContextItem(a:vmenuItems, g:VMENU#ITEM_VERSION.VMENU)
    if idx == -1
        let topMenuItem = s:TopMenuItem.new(topItem.name, topItem.hotKey, topItem.hotKeyPos, dropMenu)
        call add(s:VMenuManager.__allTopMenuItemList, topMenuItem)
    else
        call s:VMenuManager.__allTopMenuItemList[idx].appendTopMenuItems(dropMenu)
    endif
endfunction
function! vmenu#openTopMenu()
    if empty(s:VMenuManager.__allTopMenuItemList)
        call s:printWarn("vmenu: top menu is empty!")
        return
    endif

    call s:TopMenuWindow.builder()
                \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                \.build()
                \.show()
    call s:VMenuManager.startListening()
endfunction
function! vmenu#cleanTopMenu()
    let s:VMenuManager.__allTopMenuItemList = []
endfunction

" query installed items (flattened)
" opts: same as "opts" in vmenu#openContextWindow
" return: [#{id: xx, path: xx, name: xx}]
function! vmenu#queryItems(opts)
    let editorStatus = {}
    if get(a:opts, 'curMode', '') != ''
        let editorStatus = s:getEditorStatus(a:opts.curMode)
    else
        let editorStatus = s:getEditorStatus()
    endif
    let s:VMenuManager.LastEditorStatus = editorStatus

    let queryableItems = s:filterQueryableItems(
                \ s:VMenuManager.parsedContextItemList,
                \ editorStatus
                \)
    let s:VMenuManager.lastQueryableItems = queryableItems
    return reduce(queryableItems, { acc, val -> add(acc, #{id: val.id, path: val.path, name: val.name}) }, [])
endfunction

function! vmenu#executeItemById(itemId)
    let idx = indexof(s:VMenuManager.lastQueryableItems, {i, v -> v.id == a:itemId})
    if idx != -1
        let item = s:VMenuManager.lastQueryableItems[idx]
        call s:executeCmd(item['cmd'], item, s:VMenuManager.LastEditorStatus)
        call s:log("vmenu: execute item. id: " .. a:itemId)
    else
        call s:printWarn("vmenu: item not found! id: " .. a:itemId)
    endif
endfunction

function! vmenu#installContextMenu(userDefinedItems)
    let parsedItemList = s:VMenuManager.parseUserDefinedItemList(a:userDefinedItems)
    call foreach(parsedItemList, { i, v -> s:initItemPathRecursively(v, '') })
    call s:VMenuManager.saveParsedContextItemList(parsedItemList)
endfunction

function! vmenu#itemTips()
    if (s:VMenuManager.__focusedWindow.isOpen == 1 && has_key(s:VMenuManager.__focusedWindow, 'getFocusedItemTips'))
        return s:VMenuManager.__focusedWindow.getFocusedItemTips()
    else
        return ''
    endif
endfunction

function! vmenu#existFileType(ft)
    return { editorStatus -> s:existFileType(a:ft) }
endfunction

function! vmenu#matchRegex(regex)
    return { editorStatus -> match(editorStatus.selectedText, a:regex) != -1 }
endfunction

"-------------------------------------------------------------------------------
" utils
"-------------------------------------------------------------------------------
function! s:printWarn(msg)
    echohl WarningMsg | echo a:msg | echohl None
    call s:log(a:msg, "WARN")
endfunction

function! s:log(msg, level="INFO")
    if s:enable_log == 1
        call s:echom(printf("%s [%s] %s", strftime("%T"), a:level, a:msg))
    endif
endfunction

function! s:echom(msg)
    echom a:msg
    "call writefile([a:msg], "vmenu.log", "a")
endfunction

function! s:existFileType(ft)
    for i in range(1, winnr('$'))
        if getbufvar(winbufnr(i), '&filetype') == a:ft
            return 1
        endif
    endfor

    return 0
endfunction

function! s:createMousePosFromTopLeft(vmenuWindow, offsetX, offsetY)
    return #{screencol: s:VMenuManager.calcTopLeftPos(a:vmenuWindow).x + a:offsetX,
                \ screenrow: s:VMenuManager.calcTopLeftPos(a:vmenuWindow).y + a:offsetY}
endfunction

function! s:executeCmd(Cmd, item, editorStatus)
    if type(a:Cmd) == v:t_string
        if strwidth(a:Cmd) > 0
            call execute(a:Cmd)
        endif
    endif

    if type(a:Cmd) == v:t_func
        call a:Cmd(s:createCallbackItemParm(a:item), a:editorStatus)
    endif
endfunction

function! s:event2String(event)
    let workingEvent = deepcopy(a:event, 1)
    let workingEvent.key = keytrans(workingEvent.key)   " convert to a readable format
    return string(workingEvent)
endfunction

" only used in testing
let s:testList = []
function! vmenu#testEcho(msg)
    call add(s:testList, a:msg)
endfunction

" only used in testing
let s:errorList = []


"-------------------------------------------------------------------------------
" interface
"-------------------------------------------------------------------------------
" get the text list and highlight in the window
function! s:dumpContent() dict
    return #{textList: [], highlight: []}   "
endfunction

function! s:getFocusedItemTips() dict
    return ""
endfunction


"-------------------------------------------------------------------------------
" test
"-------------------------------------------------------------------------------

function! s:showErrors()
    let opts = {}
    let opts.w = 170
    let opts.h = 10
    let opts.title = ' errors '
    let opts.padding = [0, 1, 0, 1]
    let text = []
    for err in v:errors
        call add(text, string(err))
    endfor
    call insert(text, printf("[%s] tests failed!", len(text)), 0)
    call insert(text, "", 1)
    call add(text, "")
    call add(text, " press any key to close...")

    let win = quickui#window#new()
    call win.open(text, opts)

    call win.show(1)
    call win.center()
    redraw
    call getchar()
    call win.close()
endfunction

" <TEST-FLAG>
if 0

    let v:errors = []
    let s:enable_log = 0
    let s:min_context_menu_width = 0
    let s:doc_window_scroll_down_key = "\<C-E>"
    let s:doc_window_scroll_up_key = "\<C-Y>"

    " vmenu item parse test
    if 0
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0123456789', cmd: 'echom 1', tip: 'tip', icon: '', show-mode: ['n', 'v'], subItemList: [#{name: 'sub name', cmd: 'echom 1.1', tip: 'tip', icon: '', show-mode: ['n', 'v'], deactive-mode: ['n', 'v']}]},
                    \#{name: '0123456789', cmd: 'echom 2', tip: 'tip', icon: ' ', show-mode: ['n', 'v'], subItemList: [#{name: 'sub name', cmd: 'echom 1.2', tip: 'tip', icon: '', show-mode: ['n', 'v'], deactive-mode: ['n', 'v']}]},
                    \#{name: '0123456789', cmd: 'echom 3', tip: 'tip', icon: '', show-mode: ['n', 'v'], subItemList: [#{name: 'sub name', cmd: 'echom 1.3', tip: 'tip', icon: '', show-mode: ['n', 'v'], deactive-mode: ['n', 'v']}]},
                    \#{name: '&Hi', cmd: 'echom 6', tip: 'tip', icon: '', show-mode: ['n', 'v']},
                    \#{isSep: 1},
                    \#{name: 'inactive in normal mode', cmd: 'echom 6', tip: 'tip', icon: '', deactive-mode: ['n']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " fill name to same length test
    if 1
        call s:VMenuManager.parseContextItem([
                    \["1", ""],
                    \["12", ""]
                    \])
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["1", ""],
                    \["12", ""]
                    \]))
                    \.build()
                    \.showAtCursor()
        call assert_equal("   1   ", s:VMenuManager.__focusedWindow.contextItemList[0].name)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " seperator line test
    if 1
        " quickui item
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["-"]
                    \]))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[0].isSep)
        call assert_equal(" ——— ", s:VMenuManager.__focusedWindow.contextItemList[0].name)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        " vmenu item
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{isSep: 1},
                    \#{name: '1'},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[0].isSep)
        call assert_equal(" ———— ", s:VMenuManager.__focusedWindow.contextItemList[0].name)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " origin vim-quickui context item parse test
    if 1
        let contextItem = s:ItemParser.parseQuickuiItem(["&Hello\tCtrl+h", 'echo 1', 'test help'])
        call assert_equal("Hello", contextItem.name, "name parse failed!")
        call assert_equal("Ctrl+h", contextItem.shortKey, "shortKey parse failed!")
        call assert_equal(0, contextItem.hotKeyPos, "hotKeyPos parse failed!")
        call assert_equal('H', contextItem.hotKey, "hotKey parse failed!")
        call assert_equal('echo 1', contextItem.cmd, "cmd parse failed!")
        call assert_equal('test help', contextItem.tip, "tip parse failed!")
    endif

    " leo-fp/vim-quickui item parse test
    if 1
        let contextItem = s:ItemParser.parseQuickuiItem(#{text: "C&opy", cmd: 'echo 2', help: 'copy', icon:''})
        call assert_equal("Copy", contextItem.name, "name parse failed!")
        call assert_equal(1, contextItem.hotKeyPos, "hotKeyPos parse failed!")
        call assert_equal('o', contextItem.hotKey, "hotKey parse failed!")
        call assert_equal('echo 2', contextItem.cmd, "cmd parse failed!")
        call assert_equal('', contextItem.icon, "icon parse failed!")
    endif

    " vmenu item parse test
    if 1
        let contextItem = s:ItemParser.parseVMenuItem(#{name: "&Hi\tCtrl-c", cmd: 'echom 6', tip: 'tip', icon: 'icon', show-mode: ['n', 'v']})
        call assert_equal("Hi", contextItem.name, "name parse failed!")
        call assert_equal(0, contextItem.hotKeyPos, "hotKeyPos parse failed!")
        call assert_equal('H', contextItem.hotKey, "hotKey parse failed!")
        call assert_equal('echom 6', contextItem.cmd, "cmd parse failed!")
        call assert_equal('icon', contextItem.icon, "icon parse failed!")
        call assert_equal("Ctrl-c", contextItem.shortKey, "shortKey parse failed!")
    endif

    " second menu parse test
    if 1
        let contextItem = s:ItemParser.parseQuickuiItem(["first menu", 'call quickui#context#expand([["second menu", "echo 1"]])'])
        call assert_equal("second menu", contextItem.subItemList[0].name, "name parse failed!")
        call assert_equal('', contextItem.cmd, "cmd parse failed!")
    endif

    " isOpen test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["hi", '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " when cmd is executed, close all context window
    if 1
        let window = s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["first menu", 'call quickui#context#expand([["second menu", "echo 1"]])']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal(1, window.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal(0, window.isOpen)
    endif

    " execute cmd by hotkey
    if 1
        let msg = rand(srand())
        let window = s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["&Hi", 'call vmenu#testEcho(' .. msg .. ')']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("h"))
        call assert_equal(0, window.isOpen)
        call assert_true(index(s:testList, msg) != -1)

        " expand by hotkey
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: "&a", subItemList: [#{name: '1.1', cmd: ''}]},
                    \#{name: "&b", subItemList: [#{name: '2.1', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("a"))
        call assert_equal("1.1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " open second menu by hotkey, then execute cmd by hotkey
    if 1
        let msg = rand(srand())
        let secondMenuCmd = 'call vmenu#testEcho(' .. msg .. ')'
        let window = s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["&first menu 1449874988", 'call quickui#context#expand([["&second menu", "' .. secondMenuCmd .. '"]])']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("f"))
        call assert_equal(1, window.subVmenuWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("s"))
        call assert_equal(0, window.subVmenuWindow.isOpen)
        call assert_equal(0, window.isOpen)
        call assert_true(index(s:testList, msg) != -1)
    endif

    " test context item tip
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["first menu", 'call quickui#context#expand([["second menu", "echo 1", "second"]])', 'first'],
                    \["&Hello\tCtrl+h", 'echo 1', 'test help']
                    \]))
                    \.build()
                    \.showAtCursor()
        call assert_equal('first', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal('second', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal('first', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal('test help', vmenu#itemTips())

        " after close, tip should be cleaned
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal('', vmenu#itemTips())
    endif

    " seperator line should not be selected
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["a", 'echo 1', ''],
                    \['-'],
                    \["b", 'echo 2', '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal("b", s:VMenuManager.__focusedWindow.getCurItem().name->trim())

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("k"))
        call assert_equal("a", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " inactive item should not be selected
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'a', cmd: 'echom 1'},
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', deactive-mode: ['n']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal("a", s:VMenuManager.__focusedWindow.getCurItem().name->trim())

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " skip inactive item automatically
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'a', cmd: 'echom 1'},
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', deactive-if: { -> 1 }},
                    \#{name: 'c', cmd: 'echom 1'},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal("c", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("k"))
        call assert_equal("a", s:VMenuManager.__focusedWindow.getCurItem().name->trim())

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " show-ft test
    if 1
        call assert_equal('n', s:getEditorStatus().currentMode)
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in vim file', cmd: 'echo 1', tip: 'tip', icon: '', show-ft: ['vim']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.getCurItem().isVisible(#{currentFileType: 'vim'}))
        call assert_equal(0, s:VMenuManager.__focusedWindow.getCurItem().isVisible(#{currentFileType: 'lua'}))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " context menu hotkey position test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["Hi", ''],
                    \["&Hi", '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call assert_equal(-1, s:VMenuManager.__focusedWindow.getCurItem().hotKeyPos)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal("H", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{text: "c", cmd: "", help: '', icon:'󰆏'},
                    \["&Hi", '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal("H", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " syntaxRegionList test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["Hi", ''],
                    \]))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal(1, item.syntaxRegionList->len())
        call assert_equal(['VmenuSelect', 0, 7], item.syntaxRegionList[0])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " syntaxRegionList test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["&Hi", ''],
                    \]))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal(['VmenuSelect', 0, 3], item.syntaxRegionList[0])
        call assert_equal(['VmenuSelectedHotkey', 3, 4], item.syntaxRegionList[1])
        call assert_equal(['VmenuSelect', 4, 7], item.syntaxRegionList[2])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " the hotkey of inactive item should be redered
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '&A', cmd: '', tip: '', icon: '', deactive-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.contextItemList[1]
        call assert_equal(['VmenuInactive', 0, 3], item.syntaxRegionList[0])
        call assert_equal(['VmenuInactiveHotKey', 3, 4], item.syntaxRegionList[1])
        call assert_equal(['VmenuInactive', 4, 6], item.syntaxRegionList[2])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " desc pos test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["Hi\tdesc", ''],
                    \["hi", ''],
                    \]))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal("desc", item.name[item.descPos:item.descPos+item.descWidth-1])

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal(-1, item.descPos)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        " desc pos in vmenu item
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: "1", cmd: ''},
                    \#{name: "1\t2", cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.contextItemList[1]
        call assert_equal("2", item.name[item.descPos:item.descPos+item.descWidth-1])
        call assert_equal(['VmenuDesc', 8, 9], item.syntaxRegionList[0])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " top menu hotkey pos test
    if 1
        call s:VMenuManager.initTopMenuItems('T&est', [
                    \["Hi\tdesc", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal(3, item.hotKeyPos)
        call assert_equal("e", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " top menu hotkey invoke test
    if 1
        call s:VMenuManager.initTopMenuItems('T&est', [
                    \["Hi\tdesc", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal(3, item.hotKeyPos)
        call assert_equal("e", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("e"))
        call assert_equal("Hi    desc", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " same top menu will be initialized only once
    if 1
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('T&est-dd137fdf-13f1-4391-99e7-afaea647b450', [
                    \["Hi\tdesc", ''],
                    \])
        call s:VMenuManager.initTopMenuItems('T&est-dd137fdf-13f1-4391-99e7-afaea647b450', [
                    \["Hi\tdesc", ''],
                    \])
        call assert_equal(1, s:VMenuManager.__allTopMenuItemList->len())
    endif

    " go bottom test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \#{name: 'INACTIVE ITEM', cmd: '', deactive-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("G"))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " __fileterVisibleItems test
    if 1
        call assert_equal(2, s:filterVisibleItems(s:VMenuManager.parseContextItem([
                    \#{name: 'a', cmd: 'echom 1'},
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', show-mode: ['n']}
                    \], g:VMENU#ITEM_VERSION.VMENU), #{currentMode: "n"})->len())
    endif

    " show-if test
    if 1
        call assert_equal(1, s:filterVisibleItems(s:VMenuManager.parseContextItem([
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', show-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU), #{currentMode: "n"})->len())
        call assert_equal(0, s:filterVisibleItems(s:VMenuManager.parseContextItem([
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', show-if: { -> 0 }}
                    \], g:VMENU#ITEM_VERSION.VMENU), #{currentMode: "n"})->len())
    endif

    " deactive-mode test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in normal mode', cmd: 'echo 1', tip: 'tip', icon: '', deactive-mode: ['n']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[0].isInactive(#{currentMode: 'n'}))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " deactive-ft test
    " should be inactive
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in normal mode', cmd: 'echo 1', tip: 'tip', icon: '', deactive-ft: ['vim']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[0].isInactive(#{currentFileType: 'vim'}))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " deactive-ft test
    " should be active
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in normal mode', cmd: 'echo 1', tip: 'tip', icon: '', deactive-ft: ['lua']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(0, s:VMenuManager.__focusedWindow.getCurItem().isInactive(#{currentFileType: 'vim'}))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " deactive-if test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in normal mode', cmd: 'echo 1', tip: 'tip', icon: '', deactive-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[0].isInactive({}))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " first item is inactive. should not be executed
    if 1
        let s:errorList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive item', cmd: 'echom 6', tip: 'tip', icon: '', deactive-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.errConsumer({ msg -> add(s:errorList, msg) })
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal("vmenu: current item is not executable!", s:errorList[0])
    endif

    " inactive context item should not be executed by hotkey
    if 1
        let s:errorList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: '', tip: '', icon: ''},
                    \#{name: '&inactive item', cmd: '', tip: '', icon: '', deactive-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.errConsumer({ msg -> add(s:errorList, msg) })
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("i"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal("vmenu: no executable item for hotkey 'i'", s:errorList[0])
    endif

    " vmenu#existFileType test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: '', show-if: vmenu#existFileType("vim") },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " close context menu if clicked position is not in context window area
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, -1, -1)))
        call assert_equal(0, s:VMenuManager.__focusedWindow.isOpen)
    endif

    " seperator line should not be clicked
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: ''},
                    \#{isSep: 1},
                    \#{name: 'name2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " inactive item should not be clicked
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: ''},
                    \#{name: 'name2', cmd: '', deactive-if: { -> 1 }},
                    \#{name: 'name2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " focus first valid item after opening context window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', deactive-if: { -> 1 }},
                    \#{name: '2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " top menu: click and open sub menu
    if 1
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('T&est-mouse-click', [
                    \["Hi\tdesc", ''],
                    \])
        call s:VMenuManager.initTopMenuItems('&Test2-mouse-click', [
                    \["Hi2\tdesc", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 25, 0)))
        call assert_equal("   Hi2    desc  ", s:VMenuManager.__focusedWindow.getCurItem().name)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " top menu: click boundary of item
    if 1
        " right boundary
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('1', [
                    \["1", ''],
                    \])
        call s:VMenuManager.initTopMenuItems('2', [
                    \["2", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 4, 0)))
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        " left boundary
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 5, 0)))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " context menu: click event can be handled by parent window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: '', subItemList: [#{name: 'sub name', cmd: ''}]},
                    \#{name: 'name2', cmd: '', subItemList: [#{name: 'sub name2', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 0)))
        call assert_equal("sub name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow.parentVmenuWindow, 0, 1)))
        call assert_equal("sub name2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " context menu: minimal window width test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: "1\t>", cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.minWidth(20)
                    \.build()
                    \.showAtCursor()
        call assert_equal(20, s:VMenuManager.__focusedWindow.winWidth)
        "------------------01234567890123456789
        call assert_equal('   1             >  ', s:VMenuManager.__focusedWindow.getCurItem().name)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        " seperator line
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{isSep: 1},
                    \#{name: '1', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.minWidth(10)
                    \.build()
                    \.showAtCursor()
        call assert_equal(10, s:VMenuManager.__focusedWindow.winWidth)
        "------------------0123456789
        call assert_equal(" ———————— ", s:VMenuManager.__focusedWindow.contextItemList[0].name)
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        " withth is negative
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: "1", cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.minWidth(-10)
                    \.build()
                    \.showAtCursor()
        "------------------012345
        call assert_equal('   1  ', s:VMenuManager.__focusedWindow.getCurItem().name)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " top menu: append quickui top menu with vmenu item
    if 1
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('T&est-dd137fdf-13f1-4391-99e7-afaea647b450', [
                    \["1", ''],
                    \] + vmenu#parse_context([
                    \#{name: '2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call assert_equal(2, s:VMenuManager.__allTopMenuItemList[0].contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " do nothing if sub menu are empty in top menu
    if 1
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('T&est-empty-sub-menu', [])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal("Test-empty-sub-menu", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal(0, s:VMenuManager.__focusedWindow.isOpen)
    endif

    " editorStatusSupplier test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: ''},
                    \#{name: 'name2', cmd: '', show-mode: ['n']},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'v' } })
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: '', show-mode: ['v']},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'v' } })
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', subItemList: [#{name: '2', cmd: '', show-mode: ['v']}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'v' } })
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " vmenu#matchRegex test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', show-if: vmenu#matchRegex("hello") },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'v', selectedText: "hello" } })
                    \.build()
                    \.showAtCursor()
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " do not get selected text in normal mode
    if 1
        call assert_equal("", s:getEditorStatus().selectedText)
    endif

    " group test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '' },
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{name: '1', cmd: '' },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(5, s:VMenuManager.__focusedWindow.contextItemList->len())
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[1].isSep)
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[3].isSep)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{name: '1', cmd: '' },
                    \#{name: '1', cmd: '' },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(4, s:VMenuManager.__focusedWindow.contextItemList->len())
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[1].isSep)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '' },
                    \#{name: '1', cmd: '' },
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(4, s:VMenuManager.__focusedWindow.contextItemList->len())
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[2].isSep)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '' },
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{name: '1', cmd: '' },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(6, s:VMenuManager.__focusedWindow.contextItemList->len())
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[1].isSep)
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[4].isSep)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{isSep: 1},
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{isSep: 1},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: '', group: "g1" },
                    \#{name: '3', cmd: '', group: "g2" },
                    \#{name: '4', cmd: '', group: "g1" },
                    \#{name: '5', cmd: '', group: "g2" },
                    \#{name: '6', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(9, s:VMenuManager.__focusedWindow.contextItemList->len())
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[1].isSep)
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[4].isSep)
        call assert_equal("4", s:VMenuManager.__focusedWindow.contextItemList[3].name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " cmd can be funcref
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: { callbackItemParam, editorStatus -> assert_equal("TEST-MODE" , editorStatus.currentMode) }},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'TEST-MODE' } })
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " callbackItemParam should contains origin name
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: { callbackItemParam, editorStatus -> assert_equal("1" , callbackItemParam.name) }},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " the order should be kept
    if 1
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('T&est-4e6a9e1b-31e0-49ae-a670-ec0e248ba821', [
                    \["1", ''],
                    \vmenu#parse_context([#{name: '2', cmd: ''}], g:VMENU#ITEM_VERSION.VMENU)[0],
                    \["3", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal("2", s:VMenuManager.__allTopMenuItemList[0].contextItemList[1].name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " on_focus test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', onFocus: { callbackItemParam, editorStatus -> vmenu#testEcho("6af05433-6cc3-4fb3-9040-ec8139390709") }},
                    \#{name: '1', cmd: '', onFocus: 'call vmenu#testEcho("e65d3d2f-5e0a-4481-9b99-079ee09e9825")'},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal("1", s:VMenuManager.__allTopMenuItemList[0].contextItemList[0].name->trim())
        call assert_true(index(s:testList, "6af05433-6cc3-4fb3-9040-ec8139390709") != -1)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_true(index(s:testList, "e65d3d2f-5e0a-4481-9b99-079ee09e9825") != -1)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " render index changes when scrolling
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(1)
                    \.build()
                    \.showAtCursor()
        call assert_equal(0, s:VMenuManager.__focusedWindow.renderStartIdx)
        call assert_equal(0, s:VMenuManager.__focusedWindow.renderEndIdx)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.renderStartIdx)
        call assert_equal(1, s:VMenuManager.__focusedWindow.renderEndIdx)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("k"))
        call assert_equal(0, s:VMenuManager.__focusedWindow.renderStartIdx)
        call assert_equal(0, s:VMenuManager.__focusedWindow.renderEndIdx)

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " test focused item syntax when scrolling down
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(1)
                    \.build()
                    \.showAtCursor()
        call assert_true([] != filter(copy(s:VMenuManager.__focusedWindow.getCurItem().syntaxRegionList), {idx, val -> val == ['VmenuSelect', 0, 5]}))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call assert_true([] != filter(copy(s:VMenuManager.__focusedWindow.getCurItem().syntaxRegionList), {idx, val -> val == ['VmenuSelect', 0, 5]}))

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " test scroll bar reaches the bottom when focusing last item
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem(
                    \ map(range(80),
                    \  { idx, val
                    \  -> #{
                    \       name: val,
                    \       cmd: ''
                    \      }
                    \  })
                    \, g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(10)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("G"))
        call assert_equal([
                    \#{highlight: "VmenuScrollbar", x1: 0, y1: 8, x2: 1, y2: 8},
                    \#{highlight: "VmenuScrollbar", x1: 0, y1: 9, x2: 1, y2: 9}
                    \], s:VMenuManager.__focusedWindow.scrollbarWindow.dumpContent().highlight)

        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " show scrollbar when item size > winHeight
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(20)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal(['VmenuSelect', 0, 6], s:VMenuManager.__focusedWindow.getCurItem().syntaxRegionList[0])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: ''},
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \#{name: '3', cmd: ''},
                    \#{name: '4', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal(['VmenuSelect', 0, 6], s:VMenuManager.__focusedWindow.getCurItem().syntaxRegionList[0])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: ''},
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \#{name: '3', cmd: ''},
                    \#{name: '4', cmd: ''},
                    \#{name: '5', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal([
                    \#{highlight: "VmenuScrollbar", x1: 0, y1: 0, x2: 1, y2: 0},
                    \#{highlight: "VmenuScrollbar", x1: 0, y1: 1, x2: 1, y2: 1}
                    \], s:VMenuManager.__focusedWindow.scrollbarWindow.dumpContent().highlight)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " mouse clicking will get right index when scrollbar is activated
    if 1
        let s:testList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: 'call vmenu#testEcho(0)'},
                    \#{name: '1', cmd: 'call vmenu#testEcho(1)'},
                    \#{name: '2', cmd: 'call vmenu#testEcho(2)'},
                    \#{name: '3', cmd: 'call vmenu#testEcho(3)'},
                    \#{name: '4', cmd: 'call vmenu#testEcho(4)'},
                    \#{name: '5', cmd: 'call vmenu#testEcho(5)'},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("G"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 0)))
        call assert_true(index(s:testList, 1) != -1)
    endif

    " click below the scrolling widnow will close all windows
    if 1
        let s:testList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: ''},
                    \#{name: '1', cmd: ''},
                    \#{name: '2', cmd: ''},
                    \#{name: '3', cmd: ''},
                    \#{name: '4', cmd: ''},
                    \#{name: '5', subItemList: [#{name: '5.1', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseClickEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 5)))
        call assert_equal(0, s:VMenuManager.__focusedWindow.isOpen)
    endif

    " (context menu) focus on item when mouse hovering
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: ''},
                    \#{name: '1', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (top menu) focus on item when mouse hovering
    if 1
        call vmenu#cleanTopMenu()
        call s:VMenuManager.initTopMenuItems('1', [
                    \["Hi\tdesc", ''],
                    \])
        call s:VMenuManager.initTopMenuItems('2', [
                    \["Hi\tdesc", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 5, 0)))
        call assert_equal("2", s:VMenuManager.__focusedWindow.parentVmenuWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu) auto expand if there are subItemList in item when mouse hovering
    " sub window should not focus any item
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: ''},
                    \#{name: '1', subItemList: [#{name: "1.1", cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len()) " focus sub window
        call assert_equal(-1, s:VMenuManager.__focusedWindow.__curItemIndex)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (top menu) auto expand if there are subItemList in item when mouse hovering
    " sub window should not focus any item
    if 1
        call vmenu#cleanTopMenu()
        call s:VMenuManager.initTopMenuItems('1', [
                    \["Hi\tdesc", ''],
                    \])
        call s:VMenuManager.initTopMenuItems('2', [
                    \["Hi\tdesc", ''],
                    \])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 5, 0)))
        call assert_equal(-1, s:VMenuManager.__focusedWindow.__curItemIndex)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu) seperator line should not be focus when mouse hovering
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', cmd: ''},
                    \#{isSep: 1},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal("0", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu) parent window can respond to mouse hover event even if sub menu is opening
    if 1
        let window = s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '0', subItemList: [#{name: "0.1", cmd: '', subItemList: [#{name: '0.1.1', cmd: ''}]}]},
                    \#{name: '1', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call window.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 0, 0)))
        call assert_equal("0.1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len()) " focus sub window
        call assert_equal(-1, s:VMenuManager.__focusedWindow.__curItemIndex)
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 0)))
        call assert_equal("0.1.1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call window.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 0, 1)))
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (top menu) top menu can respond to mouse hover event even if sub menu is opening
    if 1
        call vmenu#cleanTopMenu()
        call s:VMenuManager.initTopMenuItems('1', vmenu#parse_context([
                    \#{name: '1.1', cmd: '', subItemList: [#{name: '1.1.1', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
        call s:VMenuManager.initTopMenuItems('2', vmenu#parse_context([
                    \#{name: '2.1', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
        let window = s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        "call s:VMenuManager.startListening()
        call window.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 0, 0)))
        call assert_equal("1.1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call assert_equal(-1, s:VMenuManager.__focusedWindow.__curItemIndex)
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 0)))
        call assert_equal("1.1.1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call window.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 5, 0)))
        call assert_equal("2", window.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu) context menu should not close if mouse hover event occured outside the window
    " region
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, -1, -1)))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu) only create one vmenu window if mouse hovering in same item
    if 1
        let window = s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', subItemList: [#{name: "1.1", cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.winHeight(5)
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 0, 0)))
        let winIdAtFirstTime = string(window.subVmenuWindow.winId)
        call s:log(winIdAtFirstTime)
        call window.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 0, 1)))
        call window.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(window, 0, 0)))
        let winIdAtSecondTime = string(window.subVmenuWindow.winId)
        call s:log(winIdAtSecondTime)
        call assert_equal(winIdAtFirstTime, winIdAtSecondTime)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " the first item in a window that expanded by mouse hovering should not be executed by pressing <CR>
    if 1
        let s:errorList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1.1', cmd: '', subItemList: [#{name: '1.1.1', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.errConsumer({ msg -> add(s:errorList, msg) })
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 0)))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("vmenu: there is no focused item!", s:errorList[0])
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " open a window on the far right, child window and grandchild window need to be opened on left side
    if 1
        let window = s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', subItemList: [#{name: '2', cmd: '', subItemList: [#{name: '3', cmd: ''}]}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAt(&columns, 0)   " set x to &columns to make sure the first window opened on the far right
        call window.__focusFirstMatch([0])
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        let secondMenuPos = s:VMenuManager.calcTopLeftPos(s:VMenuManager.__focusedWindow)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        let thirdMenuPos = s:VMenuManager.calcTopLeftPos(s:VMenuManager.__focusedWindow)
        call assert_true(thirdMenuPos.x < secondMenuPos.x)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu) item path test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', subItemList: [#{name: '2', cmd: '', subItemList: [#{name: '3', cmd: ''}]}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal('1', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal('1 > 2', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal('1 > 2 > 3', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (context menu. quickui item) item path test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["1", 'call quickui#context#expand([["2", "echo 1"]])']
                    \]))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal('1', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal('1 > 2', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (topmenu) item path test
    if 1
        call vmenu#cleanTopMenu()
        call s:VMenuManager.initTopMenuItems('&1', [
                    \vmenu#parse_context([#{name: '2', cmd: ' ', subItemList: [#{name: '3', cmd: ' '}]}], g:VMENU#ITEM_VERSION.VMENU)[0],
                    \ [ "vim-quickui item name", ' ', ""]
                    \]
                    \)
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call assert_true(-1 != indexof(vmenu#queryItems({}), {i, v -> v.path == "1 > vim-quickui item name"}))
        call assert_equal('1', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal('1 > 2', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal('1 > 2 > 3', s:VMenuManager.__focusedWindow.getCurItem().path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " (topmenu) test for parsed item count
    if 1
        let s:VMenuManager.parsedContextItemList = []
        call vmenu#cleanTopMenu()
        call s:VMenuManager.initTopMenuItems('1', vmenu#parse_context([
                    \#{name: '2', cmd: '', subItemList: [#{name: '3', cmd: ' '}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call assert_equal(1, vmenu#queryItems({})->len())    " only executable item can be saved
        call assert_equal('1 > 2 > 3', vmenu#queryItems({})[0].path)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " vmenu#installContextMenu test
    if 1
        let s:VMenuManager.parsedContextItemList = []
        call vmenu#installContextMenu([
            \ ["vim-quickui item", ' '],
            \ vmenu#parse_context([#{name: "vmenu item", cmd: " ", subItemList: [#{name: '1', cmd: ' '}]}], g:VMENU#ITEM_VERSION.VMENU)[0]
            \])
        call assert_equal(2, vmenu#queryItems({})->len())
        call assert_true(-1 != indexof(vmenu#queryItems({}), {i, v -> v.path == "vim-quickui item"}))
        call assert_true(-1 != indexof(vmenu#queryItems({}), {i, v -> v.path == "vmenu item > 1"}))
    endif

    " vmenu#queryItems test
    if 1
        let s:VMenuManager.parsedContextItemList = []
        call vmenu#installContextMenu([
                    \ ["vim-quickui item", ' '],
                    \ vmenu#parse_context([
                    \   #{name: "2", cmd: " ", subItemList: [#{name: '2.1', cmd: ' ', show-mode: ['n']}]},
                    \], g:VMENU#ITEM_VERSION.VMENU)[0],
                    \ vmenu#parse_context([
                    \   #{name: "3", cmd: " ", subItemList: [#{name: '3.1', cmd: ' ', show-mode: ['v']}]},
                    \], g:VMENU#ITEM_VERSION.VMENU)[0]
                    \])
        let items = vmenu#queryItems(#{curMode: 'v'})
        call assert_equal(2, items->len())
        call assert_true(-1 != indexof(items, {i, v -> v.name == "3.1"}))
        call assert_true(-1 != indexof(items, {i, v -> v.name == "vim-quickui item"}))
    endif

    " separator line should not be saved
    if 1
        let s:VMenuManager.parsedContextItemList = []
        call vmenu#installContextMenu([
                    \ "--",
                    \ vmenu#parse_context([
                    \   #{isSep:1},
                    \], g:VMENU#ITEM_VERSION.VMENU)[0],
                    \])
        call assert_equal(0, vmenu#queryItems({})->len())
    endif

    " inactive item should not be queryable
    if 1
        let s:VMenuManager.parsedContextItemList = []
        call vmenu#installContextMenu(vmenu#parse_context([
                    \#{name: '1', cmd: '', deactive-if: { -> 1 }}
                    \], g:VMENU#ITEM_VERSION.VMENU))
        call assert_equal(0, vmenu#queryItems({})->len())
    endif

    " if parent item is not queryable, the sub items should not be queryable
    if 1
        let s:VMenuManager.parsedContextItemList = []
        call vmenu#installContextMenu(vmenu#parse_context([
                    \#{name: '1', deactive-if: { -> 1 }, subItemList: [#{name: '1.1', cmd: ''}]},
                    \#{name: '2', subItemList: [#{name: '2.1', deactive-if: { -> 1 }, subItemList: [#{name: '2.1.1', cmd: ' '}]}]}
                    \], g:VMENU#ITEM_VERSION.VMENU))
        call assert_equal(0, vmenu#queryItems({})->len())
    endif

    " if the 'cmd' filed of an item is empty, it should not be queryable
    if 1
        let s:VMenuManager.parsedContextItemList = []
        let s:testList = []
        call vmenu#installContextMenu([vmenu#parse_context([
                    \ #{name: '1', onFocus: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU)[0]
                    \])
        call assert_equal(0, vmenu#queryItems({})->len())
    endif

    " vmenu#executeItemById test
    if 1
        let s:VMenuManager.parsedContextItemList = []
        let s:testList = []
        call vmenu#installContextMenu([vmenu#parse_context([
                    \ #{name: '1', subItemList: [#{name: "1.1", cmd: { -> vmenu#testEcho('8d14530b-8381-44ac-821a-f95a1b556d69') }}]},
                    \], g:VMENU#ITEM_VERSION.VMENU)[0]
                    \])
        let items = vmenu#queryItems({})
        call vmenu#executeItemById(items[0].id)
        call assert_true(index(s:testList, '8d14530b-8381-44ac-821a-f95a1b556d69') != -1)
    endif

    " doc window test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', cmd: ' ', doc: ["hello", "vmenu"]},
                    \ #{name: '2', cmd: ' ', doc: ["hello", "vmenu2"]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        let docWindow1 = s:VMenuManager.__focusedWindow
        call assert_equal(["hello", "vmenu"], docWindow1.dumpContent().textList)
        call docWindow1.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal(["hello", "vmenu2"], s:VMenuManager.__focusedWindow.dumpContent().textList)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal(0, s:VMenuManager.__focusedWindow.isOpen)
        call assert_equal(0, s:VMenuManager.__focusedWindow.parentVmenuWindow.isOpen)
        call assert_equal(0, docWindow1.isOpen)
    endif

    " if both the doc and subItemList are present, doc window should not be displayed
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', doc: ["hello", "vmenu"], subItemList: [#{name: '1.1', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal(0, s:VMenuManager.__focusedWindow.isOpen)
    endif

    " test chinese text width in doc and context menu
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', doc: ["一二三", "四五六"]},
                    \ #{name: '一二三', cmd: ''}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal(6, s:VMenuManager.__focusedWindow.winWidth)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("j"))
        call assert_equal(11, s:VMenuManager.__focusedWindow.winWidth)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call assert_equal(0, s:VMenuManager.__focusedWindow.isOpen)
    endif

    " if the space on both left and right sides can not hold the doc window, the doc
    " window should be moved down one line to prevent obscuring current item.
    if 1
        call vmenu#cleanTopMenu()
        call s:VMenuManager.initTopMenuItems('1', vmenu#parse_context([
                    \ #{name: '1', doc: [repeat('-', &columns)]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<CR>"))
        call assert_equal(s:VMenuManager.__focusedWindow.parentVmenuWindow.y+1, s:VMenuManager.__focusedWindow.y)
        call assert_equal(1, s:VMenuManager.__focusedWindow.winHeight)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " display partial text if text list exceeds max doc window height
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', doc: range(4) + ["abc"]},
                    \ #{name: '2', cmd: ''},
                    \ #{name: '3', cmd: ''},
                    \ #{name: '4', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{lines: 4 } })
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal([0, 1, 2], s:VMenuManager.__focusedWindow.dumpContent().textList)
        call assert_equal(4, s:VMenuManager.__focusedWindow.winWidth)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " test scrolling down and scroll up in doc window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', doc: range(4)},
                    \ #{name: '2', cmd: ''},
                    \ #{name: '3', cmd: ''},
                    \ #{name: '4', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{lines: 4 } })
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<C-E>"))
        call assert_equal([1, 2, 3], s:VMenuManager.__focusedWindow.dumpContent().textList)
        " reach the bottom. keep as is
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<C-E>"))
        call assert_equal([1, 2, 3], s:VMenuManager.__focusedWindow.dumpContent().textList)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<C-Y>"))
        call assert_equal([0, 1, 2], s:VMenuManager.__focusedWindow.dumpContent().textList)
        " reach the top. keep as is
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<C-Y>"))
        call assert_equal([0, 1, 2], s:VMenuManager.__focusedWindow.dumpContent().textList)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " test scrollbar in doc window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', doc: range(4)},
                    \ #{name: '2', cmd: ''},
                    \ #{name: '3', cmd: ''},
                    \ #{name: '4', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{lines: 4 } })
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        call assert_equal([0, 1, 2], s:VMenuManager.__focusedWindow.dumpContent().textList)
        call assert_equal([
                    \#{highlight: "VmenuDocWindowScrollbar", x1: 0, y1: 0, x2: 1, y2: 0},
                    \#{highlight: "VmenuDocWindowScrollbar", x1: 0, y1: 1, x2: 1, y2: 1}],
                    \s:VMenuManager.__focusedWindow.scrollbarWindow.dumpContent().highlight)
        call assert_equal(s:VMenuManager.__focusedWindow.x+1,
                    \s:VMenuManager.__focusedWindow.scrollbarWindow.x)
        call assert_equal(s:VMenuManager.__focusedWindow.y,
                    \s:VMenuManager.__focusedWindow.scrollbarWindow.y)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " when hovering an inactive item
    " cancel the highlight of focused item
    " close doc window
    " close child menu
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{name: '1', cmd: '', doc: ["hello"]},
                    \ #{name: '2', cmd: '', subItemList: [#{name: "2.1", cmd: ''}]},
                    \ #{name: '3', cmd: '', deactive-if: { -> 1 }},
                    \ #{name: '4', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startListening()
        let mainWindow = s:VMenuManager.__focusedWindow.parentVmenuWindow
        call assert_equal(['VmenuSelect', 0, 6], mainWindow.getCurItem().syntaxRegionList[0])
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(mainWindow, 0, 2)))
        call assert_equal([], s:VMenuManager.__focusedWindow.getCurItem().syntaxRegionList)
        call assert_equal(0, s:VMenuManager.__focusedWindow.docWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(mainWindow, 0, 1)))
        call s:VMenuManager.__focusedWindow.handleEvent(s:MouseHoverEvent.new(s:createMousePosFromTopLeft(mainWindow, 0, 2)))
        call assert_equal(0, s:VMenuManager.__focusedWindow.subVmenuWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleEvent(s:KeyStrokeEvent.new("\<ESC>"))
    endif

    " ScrollbarWindow test
    if 1
        let scrollbarWidow = s:ScrollbarWindow.new(5, 10, 2)
                    \.showAt(0, 0)
        call assert_equal(['█', '█', ' ', ' ', ' '], scrollbarWidow.dumpContent().textList)
        call assert_equal([
                    \#{highlight: "VmenuDocWindowScrollbar", x1: 0, y1: 0, x2: 1, y2: 0},
                    \#{highlight: "VmenuDocWindowScrollbar", x1: 0, y1: 1, x2: 1, y2: 1}],
                    \scrollbarWidow.dumpContent().highlight)
        call scrollbarWidow.update(5)
        call assert_equal([' ', ' ', ' ', '█', '█'], scrollbarWidow.dumpContent().textList)
        call scrollbarWidow.close()
        call assert_equal(0, scrollbarWidow.isOpen)
    endif

    call s:showErrors()
endif
