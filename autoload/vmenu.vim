"MIT License
"
"Copyright (c) 2025 leo-fp
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
let g:VMENU#ITEM_VERSION = #{QUICKUI: 1, VMENU: 2}

"-------------------------------------------------------------------------------
" config
"-------------------------------------------------------------------------------
let s:enable_log = get(g:, "vmenu_enable_log", 0)
let s:enable_echo_tips = get(g:, "vmenu_enable_echo_tips", 1)

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
" class InputEvent
"-------------------------------------------------------------------------------
let s:InputEvent = {}
function! s:InputEvent.new(char, clickPos=#{screencol: -1, screenrow: -1})
    let inputEvent = deepcopy(s:InputEvent, 1)
    let inputEvent.char = a:char
    let inputEvent.mousepos = a:clickPos
    return inputEvent
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
    let vmenuWindowBuilder.__traceId             = ''   " a text that will be printed in log. for debug
    let vmenuWindowBuilder.__errConsumer = function("s:printWarn")
    let vmenuWindowBuilder.__minWidth = 0   " minimal window width. only supported in context menu
    let vmenuWindowBuilder.__editorStatusSupplier = function("s:getEditorStatus")
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
function! s:VmenuWindowBuilder.traceId(traceId)
    let self.__traceId = a:traceId
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
function! s:VmenuWindowBuilder.editorStatusSupplier(editorStatusSupplier)
    let self.__editorStatusSupplier = a:editorStatusSupplier
    return self
endfunction
function! s:VmenuWindowBuilder.build()
endfunction

"-------------------------------------------------------------------------------
" class VmenuWindow. base class
"-------------------------------------------------------------------------------
let s:VmenuWindow = {}
function! s:VmenuWindow.new()
    let vmenuWindow = deepcopy(s:VmenuWindow, 1)
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
    let vmenuWindow.__delayTime = 0
    let vmenuWindow.__goBottomKey = ''
    let vmenuWindow.__traceId = ''
    let vmenuWindow.__actionMap = {}
    let vmenuWindow.__errConsumer = function("s:printWarn")
    let vmenuWindow.__curItemIndex = -1
    let vmenuWindow.__componentLength = 0
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
function! s:VmenuWindow.executeByLeftMouse(inputEvent)
    " calculate index of clicked item
    let clickedIdx = self.getClickedItemIndex(a:inputEvent.mousepos)
    call self.__logger.info("will focus at: " .. clickedIdx)

    " close all vmenu window
    if clickedIdx == -1
        call self.close(s:NOT_IN_AREA, a:inputEvent)
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
function! s:VmenuWindow.close(closeCode, userInput={})
    call self.quickuiWindow.close()
    let self.isOpen = 0
    if has_key(self, 'parentVmenuWindow') && !empty(self.parentVmenuWindow)
        call self.parentVmenuWindow.__onSubMenuClose(a:closeCode, a:userInput)
    endif

    " root window, stop getting user input
    if !has_key(self, 'parentVmenuWindow') || empty(self.parentVmenuWindow)
        call s:VMenuManager.stopListen()
        " make sure no vmenu item tips left
        echo vmenu#itemTips()
    endif
endfunction

function! s:VmenuWindow.__onSubMenuClose(closeCode, userInput)
    if a:closeCode == s:CASCADE_CLOSE
        call self.close(s:CASCADE_CLOSE, a:userInput)
    else
        call s:VMenuManager.setFocusedWindow(self)
        " this will refresh tips in statusline
        call self.focusItemByIndex(self.__curItemIndex)
    endif

    " the s:NOT_IN_AREA means a mouse click event occured not in sub window.
    " let parent window try to handle this.
    if a:closeCode == s:NOT_IN_AREA
        call self.handleUserInput(a:userInput)
    endif
endfunction

" return: item index in context item list. if there is no valid item, return -1
function! s:VmenuWindow.getClickedItemIndex(mousePos)
endfunction

function! s:VmenuWindow.handleUserInput(inputEvent, doAfterKeyStroke={ contextWindow -> '' })
    if self.__delayTime != 0
        execute self.__delayTime .. 'sleep'
    endif

    call get(self.__actionMap, a:inputEvent.char, { -> { -> ''}})(a:inputEvent)()

    call a:doAfterKeyStroke(deepcopy(self, 1))
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
    let contextWindow.contextItemList = s:ContextWindow.__fileterVisibleItems(a:contextWindowBuilder.__contextItemList, a:contextWindowBuilder.__editorStatusSupplier())
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
    let contextWindow.winWidth = strcharlen(contextWindow.contextItemList[0].name)
    let contextWindow.winHeight = contextWindow.contextItemList->len()
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
    let contextWindow.__subContextWindowOpen = 0
    let contextWindow.__traceId = a:contextWindowBuilder.__traceId
    let contextWindow.__errConsumer = a:contextWindowBuilder.__errConsumer
    let contextWindow.__editorStatusSupplier = a:contextWindowBuilder.__editorStatusSupplier
    let contextWindow.isOpen = 0
    let contextWindow.parentVmenuWindow = a:contextWindowBuilder.__parentContextWindow
    let contextWindow.__logger = s:Log.new(contextWindow)
    call contextWindow.__logger.info(printf("new ContextWindow created, winId: %s", contextWindow.winId))

    let actionMap = {}
    let actionMap[a:contextWindowBuilder.__closeKey]      = { inputEvent -> function(contextWindow.close,       [s:CLOSE_SELF_ONLY, s:InputEvent.new(a:contextWindowBuilder.__closeKey)], contextWindow) }
    let actionMap[a:contextWindowBuilder.__goNextKey]     = { inputEvent -> function(contextWindow.focusNext,          [], contextWindow) }
    let actionMap[a:contextWindowBuilder.__goPreviousKey] = { inputEvent -> function(contextWindow.focusPrev,          [], contextWindow) }
    let actionMap[a:contextWindowBuilder.__goBottomKey]   = { inputEvent -> function(contextWindow.focusBottom,        [], contextWindow) }
    let actionMap[a:contextWindowBuilder.__confirmKey]    = { inputEvent -> function(contextWindow.enter,              [], contextWindow) }
    let actionMap["\<LeftMouse>"]                         = { inputEvent -> function(contextWindow.executeByLeftMouse, [inputEvent], contextWindow) }
    for hotKey in contextWindow.hotKeyList
        let actionMap[hotKey.keyChar] = { inputEvent -> function(contextWindow.executeByHotKey, [inputEvent.char], contextWindow) }
    endfor

    let contextWindow.__actionMap = actionMap
    return contextWindow
endfunction
function! s:ContextWindow.getCurItem()
    return self.contextItemList[self.__curItemIndex]
endfunction
" editorStatus: class EditorStautus
function! s:ContextWindow.__fileterVisibleItems(itemList, editorStatus)
    let activeItems = []

    for contextItem in a:itemList
        if get(contextItem, 'isVisible')(a:editorStatus) == 1
            call add(activeItems, deepcopy(contextItem, 1))
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
    let text = self.__render()
    let opts.h = self.contextItemList->len()
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
    let focusIdx = indexof(self.contextItemList, {i, v -> self.canBeFocused(i)})
    if focusIdx == -1
        call foreach(range(self.contextItemList->len()), {idx, val -> self.__renderHighlight(val)})
        redraw
    else
        call self.focusItemByIndex(focusIdx)
    endif

    call self.__logger.info(printf("ContextWindow opened at x:%s, y:%s, vmenu winId: %s,
                \ quickui winId: %s", self.x, self.y, self.winId, self.quickuiWindow.winid))
endfunction
function! s:ContextWindow.showAtCursor()
    let cursorPos = quickui#core#around_cursor(self.winWidth, self.contextItemList->len())
    call self.showAt(cursorPos[1], cursorPos[0])
endfunction

function! s:ContextWindow.getClickedItemIndex(mousePos)
    let clickedPos = #{x: a:mousePos.screencol, y: a:mousePos.screenrow}
    let topLeftCorner = s:VMenuManager.calcTopLeftPos(self)
    call self.__logger.info("clickedPos:" .. string(clickedPos))
    call self.__logger.info("topLeftCorner:" .. string(topLeftCorner))
    if (topLeftCorner.x <= clickedPos.x && clickedPos.x <= topLeftCorner.x + self.winWidth) &&
                \ (topLeftCorner.y <= clickedPos.y && clickedPos.y <= topLeftCorner.y + self.winHeight)
        return clickedPos.y - topLeftCorner.y
    endif

    return -1
endfunction

function! s:ContextWindow.focusItemByIndex(index)
    let self.__curItemIndex = a:index
    call self.__renderHighlight(a:index)
    call self.__triggerStatuslineRefresh()
    call self.__echoTipsIfEnabled()
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
function! s:ContextWindow.canBeFocused(idx)
    return self.contextItemList[a:idx].isSep == 0 && self.contextItemList[a:idx].isInactive(self.__editorStatusSupplier()) == 0
endfunction

function! s:ContextWindow.enter()
    if !self.canBeFocused(self.__curItemIndex)
        call self.__errConsumer("vmenu: current item is not executable!")
        return
    endif

    let subItemList = self.contextItemList[self.__curItemIndex].subItemList
    if (!subItemList->empty())
        call self.__expand()
    else
        call self.__execute()
    endif
endfunction
function! s:ContextWindow.__expand()
    let subItemList = self.contextItemList[self.__curItemIndex].subItemList
    let subContextWindow = s:ContextWindow.builder()
                \.contextItemList(subItemList)
                \.parentVmenuWindow(self)
                \.delay(self.__delayTime)
                \.editorStatusSupplier(self.__editorStatusSupplier)
                \.build()
    let x = self.x + self.winWidth
    let y = self.y + self.__curItemIndex

    " if there are insufficient space for sub context window at right side, then open at left side
    if self.x + self.winWidth + subContextWindow.winWidth > &columns
        let x = self.x - subContextWindow.winWidth
    endif
    call subContextWindow.showAt(x, y)
    let self.__subContextWindowOpen = 1
endfunction
function! s:ContextWindow.__execute()
    call self.close(s:CASCADE_CLOSE)
    call self.__executeCmdField("cmd")
endfunction
function! s:ContextWindow.__executeCmdField(fieldName="cmd")
    let curItem = self.contextItemList[self.__curItemIndex]
    let CmdField = curItem[a:fieldName]
    if type(CmdField) == v:t_string
        if strcharlen(CmdField) > 0
            call execute(CmdField)
            call self.__logger.info(printf("winId: %s, execute cmd: %s", self.winId, CmdField))
        endif
    endif

    if type(CmdField) == v:t_func
        call CmdField(s:createCallbackItemParm(curItem), self.__editorStatusSupplier())
        call self.__logger.info(printf("winId: %s, execute cmd(func): %s", self.winId, CmdField))
    endif
endfunction
function! s:ContextWindow.__render()
    return reduce(self.contextItemList, { acc, val -> add(acc, val.name) }, [])
endfunction
function! s:ContextWindow.__renderHighlight(offset)
    let win = self.quickuiWindow

    call win.syntax_begin(1)
    for index in range(len(self.contextItemList))
        " inactive item
        let curItem = self.contextItemList[index]
        let curItem.syntaxRegionList = []
        if curItem.isInactive(self.__editorStatusSupplier()) == 1
            if curItem.hotKeyPos == -1
                call add(curItem.syntaxRegionList, ["VmenuInactive", 0, index, win.opts.w, index])
            else
                call add(curItem.syntaxRegionList, ["VmenuInactive", 0, index, curItem.hotKeyPos, index])
                call add(curItem.syntaxRegionList, ["VmenuInactiveHotKey", curItem.hotKeyPos, index, curItem.hotKeyPos+1, index])
                call add(curItem.syntaxRegionList, ["VmenuInactive", curItem.hotKeyPos+1, index, win.opts.w, index])
            endif

            continue
        endif

        " focused item
        if index == a:offset
            if curItem.hotKeyPos == -1
                call add(curItem.syntaxRegionList, ["VmenuSelect", 0, index, win.opts.w, index])
            else
                call add(curItem.syntaxRegionList, ["VmenuSelect", 0, index, curItem.hotKeyPos, index])
                call add(curItem.syntaxRegionList, ["VmenuSelectedHotkey", curItem.hotKeyPos, index, curItem.hotKeyPos+1, index])
                call add(curItem.syntaxRegionList, ["VmenuSelect", curItem.hotKeyPos+1, index, win.opts.w, index])
            endif

            continue
        endif

        " hot key
        call add(curItem.syntaxRegionList, ["VmenuHotkey1", curItem.hotKeyPos, index, curItem.hotKeyPos + 1, index])

        " seperator line
        if curItem.isSep == 1
            call add(curItem.syntaxRegionList, ["VmenuSepLine", 0, index, win.opts.w, index])
        endif

        " desc
        if curItem.descPos != -1
            call add(curItem.syntaxRegionList, ["VmenuDesc", curItem.descPos, index, curItem.descPos + curItem.descWidth, index])
        endif
    endfor

    " do render
    for index in range(len(self.contextItemList))
        for syntax in self.contextItemList[index].syntaxRegionList
            call win.syntax_region(syntax[0], syntax[1], syntax[2], syntax[3], syntax[4])
        endfor
    endfor

    call win.syntax_end()
endfunction


"-------------------------------------------------------------------------------
" class ContextItem
"-------------------------------------------------------------------------------
let s:ContextItem = {}
function! s:ContextItem.new(dict)
    let contextItem                 = {}
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
    let contextItem.stretchingIndex = -1    " the index for stretching. used for minWidth
    let contextItem.syntaxRegionList       = [] " [[highlight, start column number (inclusive), start line number, end column number(exclusive), end line number]]
    let contextItem.itemVersion     = get(a:dict, 'itemVersion', 0)  " context item version. see: g:VMENU#ITEM_VERSION
    let contextItem.group           = get(a:dict, 'group', '')  " group name of current item
    return contextItem
endfunction

"-------------------------------------------------------------------------------
" class TopMenuItem
"-------------------------------------------------------------------------------
let s:TopMenuItem = {}
function! s:TopMenuItem.new(name, hotKey, hotKeyPos, contextItemList)
    let topMenuItem = deepcopy(s:TopMenuItem, 1)
    let topMenuItem.name = a:name
    let topMenuItem.hotKeyPos = a:hotKeyPos
    let topMenuItem.hotKey = a:hotKey
    let topMenuItem.contextItemList = deepcopy(a:contextItemList, 1)
    return topMenuItem
endfunction
function! s:TopMenuItem.appendTopMenuItems(contextItemList)
    call extend(self.contextItemList, deepcopy(a:contextItemList, 1))
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
    let topMenuWindow.__subContextWindowOpen = 0
    let topMenuWindow.__padding = 2 " spaces added on the left and right side for every item
    let topMenuWindow.__delayTime = a:topMenuWindowBuilder.__delayTime
    let topMenuWindow.__traceId = a:topMenuWindowBuilder.__traceId
    let topMenuWindow.__errConsumer = a:topMenuWindowBuilder.__errConsumer
    let topMenuWindow.isOpen = 0
    let topMenuWindow.__logger = s:Log.new(topMenuWindow)
    call topMenuWindow.__logger.info(printf("new TopMenuWindow created, winId: %s", topMenuWindow.winId))

    let actionMap = {}
    let actionMap[a:topMenuWindowBuilder.__closeKey]      = { inputEvent -> function(topMenuWindow.close,              [s:CLOSE_SELF_ONLY, a:topMenuWindowBuilder.__closeKey], topMenuWindow) }
    let actionMap[a:topMenuWindowBuilder.__goNextKey]     = { inputEvent -> function(topMenuWindow.focusNext,          [], topMenuWindow) }
    let actionMap[a:topMenuWindowBuilder.__goPreviousKey] = { inputEvent -> function(topMenuWindow.focusPrev,          [], topMenuWindow) }
    let actionMap[a:topMenuWindowBuilder.__goBottomKey]   = { inputEvent -> function(topMenuWindow.focusBottom,        [], topMenuWindow) }
    let actionMap[a:topMenuWindowBuilder.__confirmKey]    = { inputEvent -> function(topMenuWindow.enter,              [], topMenuWindow) }
    let actionMap["\<LeftMouse>"]                         = { inputEvent -> function(topMenuWindow.executeByLeftMouse, [inputEvent], topMenuWindow) }
    for hotKey in topMenuWindow.hotKeyList
        let actionMap[hotKey['keyChar']] = { inputEvent -> function(topMenuWindow.executeByHotKey, [inputEvent.char], topMenuWindow) }
    endfor

    let topMenuWindow.__actionMap = actionMap
    return topMenuWindow
endfunction
function! s:TopMenuWindow.getCurItem()
    return self.topMenuItemList[self.__curItemIndex]
endfunction
function! s:TopMenuWindow.show()
    let opts = {}
    let text = self.__render()
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
    call self.__logger.info(printf("TopMenuWindow opened at x:%s, y:%s, winId: %s", opts.x, opts.y, self.winId))
endfunction
function! s:TopMenuWindow.focusItemByIndex(index)
    let self.__curItemIndex = a:index
    call self.__renderHighlight(self.__curItemIndex)
    redraw
endfunction
function! s:TopMenuWindow.getFocusedItemTips()
    return ''
endfunction
function! s:TopMenuWindow.enter()
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
    let self.__subContextWindowOpen = 1
endfunction
" calculate start column to render focused top menu item
function! s:TopMenuWindow.__getStartColumnNrByIndex(index)
    return a:index == 0 ? 0
                \: reduce(self.topMenuItemList[:a:index-1], { acc, val -> acc + strcharlen(val.name) }, 0)
endfunction
function! s:TopMenuWindow.__render()
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
        call add(syntaxRegionList, ['VmenuSelect', startX, 0, startX + strcharlen(self.getCurItem().name), 0])
    else
        let startX = self.__getStartColumnNrByIndex(self.__curItemIndex) " start position in whole top menu window
        let endX = startX + item.hotKeyPos
        call add(syntaxRegionList, ['VmenuSelect', startX, 0, endX, 0])
        call add(syntaxRegionList, ["VmenuSelectedHotkey", endX, 0, endX+1, 0])
        call add(syntaxRegionList, ["VmenuSelect", endX+1, 0, startX+strcharlen(item.name), 0])
    endif
    let item.syntaxRegionList = deepcopy(syntaxRegionList, 1)
    for syntax in syntaxRegionList
        call win.syntax_region(syntax[0], syntax[1], syntax[2], syntax[3], syntax[4])
    endfor
    call win.syntax_end()
endfunction

function! s:TopMenuWindow.getClickedItemIndex(mousePos)
    let clickedPos = #{x: a:mousePos.screencol, y: a:mousePos.screenrow}
    let topLeftCorner = s:VMenuManager.calcTopLeftPos(self)
    call self.__logger.info("clickedPos:" .. string(clickedPos))
    call self.__logger.info("topLeftCorner:" .. string(topLeftCorner))
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
" class EditorStatus
"-------------------------------------------------------------------------------
let s:EditorStatus = {}
function! s:getEditorStatus(curMode="n")
    let editorStatus = deepcopy(s:EditorStatus, 1)
    let editorStatus.currentMode = a:curMode
    let editorStatus.currentFileType = &ft
    " get selected text will move the cursor to the last visual area, so only get selected text in visual mode.
    let editorStatus.selectedText = a:curMode[0:1] ==? "v" ? s:getSelectedText() : ""
    return editorStatus
endfunction


"-------------------------------------------------------------------------------
" class VMenuManager
"-------------------------------------------------------------------------------
let s:VMenuManager = {}
let s:VMenuManager.__allTopMenuItemList = []
let s:VMenuManager.__focusedWindow = {}
let s:VMenuManager.__keepGettingInput = 0
function! s:VMenuManager.parseContextItem(userItemList, itemVersion=g:VMENU#ITEM_VERSION.QUICKUI)
    let s:VMenuManager.__allContextItemList = []

    let ItemParser = function(s:ItemParser.parseQuickuiItem, [])
    if a:itemVersion == g:VMENU#ITEM_VERSION.VMENU
        let ItemParser = function(s:ItemParser.parseVMenuItem, [])
    endif
    let contextItemList = reduce(a:userItemList, { acc, val -> add(acc, ItemParser(val)) }, [])

    return deepcopy(contextItemList, 1)
endfunction
function! s:VMenuManager.initTopMenuItems(name, userItemList)
    let topItem = s:ItemParser.parseQuickuiItem([a:name])
    if indexof(self.__allTopMenuItemList, {i, v -> v.name == topItem.name}) != -1
        call s:Log.simpleLog(printf("top menu: %s already installed, ignore.", a:name))
        return
    endif

    let topMenuItem = s:TopMenuItem.new(topItem.name, topItem.hotKey,
                \ topItem.hotKeyPos, self.parseUserDefinedItemList(a:userItemList))
    call add(s:VMenuManager.__allTopMenuItemList, topMenuItem)
    return topMenuItem
endfunction
function! s:VMenuManager.parseUserDefinedItemList(userItemList)
    let IsParsedVmenuItems = { val -> type(val) == v:t_dict && has_key(val, 'itemVersion') }

    let itemList = []
    " the userItemList may mixed with vim-qucikui items and parsed vmenu items.
    " for the latter, just use directely
    for idx in range(a:userItemList->len())
        if IsParsedVmenuItems(a:userItemList[idx])
            call add(itemList, deepcopy(a:userItemList[idx], 1))
        else
            call add(itemList, s:ItemParser.parseQuickuiItem(a:userItemList[idx]))
        endif
    endfor
    return itemList
endfunction

function! s:VMenuManager.startGettingUserInput()
    let self.__keepGettingInput = 1
    while self.__keepGettingInput
        let code = getchar()

        let ch = (type(code) == v:t_number)? nr2char(code) : code

        let inputEvent = {}
        if ch == "\<LeftMouse>"
            let inputEvent = s:InputEvent.new("\<LeftMouse>", getmousepos())
        else
            let inputEvent = s:InputEvent.new(ch)
        endif

        call self.__focusedWindow.handleUserInput(inputEvent)
    endwhile
endfunction

function! s:VMenuManager.stopListen()
    let self.__keepGettingInput = 0
endfunction

 " focused context window will receive and handle input
function! s:VMenuManager.setFocusedWindow(contextWindow)
    let self.__focusedWindow = a:contextWindow
endfunction

" top left position (inclusive) of vmenu window
function! s:VMenuManager.calcTopLeftPos(vmenuWindow)
    return #{x: a:vmenuWindow.x+1, y: a:vmenuWindow.y+1}
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
    let name = quickuiItem.text
    let hotKeyPos = get(quickuiItem, 'key_pos', '')
    let hotKey    = get(quickuiItem, 'key_char', '')
    let isSep     = get(a:userItem, 'isSep', '')
    let Cmd       = get(a:userItem, 'cmd', '')
    let OnFocus   = get(a:userItem, 'onFocus', '')
    let tip       = get(a:userItem, 'tip', '')
    let icon      = get(a:userItem, 'icon', '')
    let shortKey  = get(quickuiItem, 'desc', '')
    let descPos = -1    " will be calculated when context window created
    let descWidth = get(quickuiItem, 'desc_width', 0)
    let group  = get(a:userItem, 'group', '')
    let subItemList = []
    if (has_key(a:userItem, 'subItemList'))
        for item in get(a:userItem, 'subItemList')
            call add(subItemList, s:ItemParser.parseVMenuItem(item))
        endfor
    endif
    let VisiblePredicate = function('s:alwaysTruePredicate')
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

    let DeactivePredicate = function('s:alwaysFalsePredicate')
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
                \onFocus: OnFocus
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
    let VisiblePredicate = function('s:alwaysTruePredicate')
    let DeactivePredicate = function('s:alwaysFalsePredicate')

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
                \itemVersion: g:VMENU#ITEM_VERSION.QUICKUI}
                \)
endfunction

function! s:ItemParser.__fillNameToSameLength(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    let maxNameLen = reduce(workingContextItemList, { acc, val -> max([acc, strcharlen(val.name)]) }, 0)
    for contextItem in workingContextItemList
        if strcharlen(contextItem.name) < maxNameLen
            let contextItem.name = contextItem.name .. repeat(' ', maxNameLen - strcharlen(contextItem.name))
        endif
        let contextItem.stretchingIndex = maxNameLen
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__concatenateShortKey(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    for contextItem in workingContextItemList
        let left = contextItem.name .. (empty(contextItem.shortKey) ? '' : "    ")
        let contextItem.name = left .. contextItem.shortKey
        let contextItem.descPos = strcharlen(contextItem.shortKey) > 0 ?
                    \ strcharlen(left) : -1 " adjust desc pos
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__addPaddingInContextMenu(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    for contextItem in workingContextItemList
        let paddingLeft = '  '
        let contextItem.name = paddingLeft .. contextItem.name .. '  '
        let contextItem.descPos = strcharlen(contextItem.shortKey) > 0 ?
                    \ contextItem.descPos + strcharlen(paddingLeft) : -1 " adjust desc pos
        let contextItem.stretchingIndex = contextItem.stretchingIndex + strcharlen(paddingLeft) " adjust stretching index
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
                    \ topMenuItem.hotKeyPos + strcharlen(padding) : -1 " adjust desc pos
    endfor
    return workingTopMenuList
endfunction
function! s:ItemParser.__addIcon(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    let maxIconLen = reduce(workingContextItemList, { acc, val -> max([acc, strcharlen(val.icon)]) }, 0)
    for contextItem in workingContextItemList
        let iconPart = contextItem.icon .. repeat(' ', maxIconLen-strcharlen(contextItem.icon)) .. ' '
        let contextItem.name = iconPart .. contextItem.name
        let contextItem.descPos = contextItem.descPos + strcharlen(iconPart)  " adjust desc pos
        let contextItem.hotKeyPos = contextItem.hotKeyPos == -1 ? -1 : contextItem.hotKeyPos + strcharlen(iconPart)
        let contextItem.stretchingIndex = contextItem.stretchingIndex == -1 ? -1 : contextItem.stretchingIndex + strcharlen(iconPart)
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__stretchingIfNeed(contextItemList, minWidth)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    for contextItem in workingContextItemList
        let stretchingPart = repeat(' ', max([0, a:minWidth - strcharlen(contextItem.name)]))
        let contextItem.name = strcharpart(contextItem.name, 0, contextItem.stretchingIndex)
                    \ .. stretchingPart
                    \ .. strcharpart(contextItem.name, contextItem.stretchingIndex, strcharlen(contextItem.name))
        let contextItem.descPos = strcharlen(contextItem.shortKey) > 0 ?
                    \ contextItem.descPos + strcharlen(stretchingPart) : -1 " adjust desc pos
        let contextItem.stretchingIndex = contextItem.stretchingIndex + strcharlen(stretchingPart) " adjust stretching index
    endfor
    return workingContextItemList
endfunction
function! s:ItemParser.__renderSeparatorLine(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    let width = strcharlen(a:contextItemList[0].name)
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

function! s:alwaysFalsePredicate(editorStatus)
    return 0
endfunction

function! s:alwaysTruePredicate(editorStatus)
    return 1
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
        call s:VMenuManager.startGettingUserInput()
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
    call s:TopMenuWindow.builder()
                \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                \.build()
                \.show()
    call s:VMenuManager.startGettingUserInput()
endfunction

function! vmenu#itemTips()
    if (s:VMenuManager.__focusedWindow.isOpen == 1)
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
" class Log
"-------------------------------------------------------------------------------
let s:Log = {}
function! s:Log.new(vmenuWindow)
    let log = deepcopy(s:Log, 1)
    let log.vmenuWindow = deepcopy(a:vmenuWindow, 1)
    return log
endfunction
function! s:Log.info(msg)
    if s:enable_log == 1
        call s:echom(printf("TRACEID:[%s] %s", self.vmenuWindow.__traceId, a:msg))
    endif
endfunction
function! s:Log.simpleLog(msg)
    if s:enable_log == 1
        call s:echom(a:msg)
    endif
endfunction

"-------------------------------------------------------------------------------
" utils
"-------------------------------------------------------------------------------
function! s:printWarn(msg)
    echohl WarningMsg | echo a:msg | echohl None
endfunction

function! s:echom(msg)
    echom a:msg
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

" only used in testing
let s:testList = []
function! vmenu#testEcho(msg)
    call add(s:testList, a:msg)
endfunction

" only used in testing
let s:errorList = []

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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " when cmd is executed, close all context window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["first menu", 'call quickui#context#expand([["second menu", "echo 1"]])']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"), { contextWindow -> assert_equal(1, contextWindow.isOpen) })
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"), { contextWindow -> assert_true(contextWindow.isOpen == 0 && contextWindow.parentVmenuWindow.isOpen == 0) })
    endif

    " execute cmd by hotkey
    if 1
        let msg = rand(srand())
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["&Hi", 'call vmenu#testEcho(' .. msg .. ')']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("h"), { contextWindow -> assert_equal(0, contextWindow.isOpen) })
        call assert_true(index(s:testList, msg) != -1)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        " expand by hotkey
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: "&a", subItemList: [#{name: '1.1', cmd: ''}]},
                    \#{name: "&b", subItemList: [#{name: '2.1', cmd: ''}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.traceId("xxx")
                    \.build()
                    \.showAtCursor()
        "call s:VMenuManager.startGettingUserInput()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("a"))
        call assert_equal("1.1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " open second menu by hotkey, then execute cmd by hotkey
    if 1
        let msg = rand(srand())
        let secondMenuCmd = 'call vmenu#testEcho(' .. msg .. ')'
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["&first menu 1449874988", 'call quickui#context#expand([["&second menu", "' .. secondMenuCmd .. '"]])']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("f"), { contextWindow -> assert_true(contextWindow.isOpen == 1 && contextWindow.__subContextWindowOpen == 1) })
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("s"), { contextWindow -> assert_true(contextWindow.isOpen == 0 && contextWindow.__subContextWindowOpen == 0) })
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

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal('second', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call assert_equal('first', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        call assert_equal('test help', vmenu#itemTips())

        " after close, tip should be cleaned
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        call assert_equal("b", s:VMenuManager.__focusedWindow.getCurItem().name->trim())

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("k"))
        call assert_equal("a", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        call assert_equal("a", s:VMenuManager.__focusedWindow.getCurItem().name->trim())

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " skip inactive item automatically
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'a', cmd: 'echom 1'},
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', deactive-if: function("s:alwaysTruePredicate")},
                    \#{name: 'c', cmd: 'echom 1'},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        call assert_equal("c", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("k"))
        call assert_equal("a", s:VMenuManager.__focusedWindow.getCurItem().name->trim())

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal("H", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{text: "c", cmd: "", help: '', icon:'󰆏'},
                    \["&Hi", '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal("H", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call assert_equal(['VmenuSelect', 0, 0, 7, 0], item.syntaxRegionList[0])
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call assert_equal(['VmenuSelect', 0, 0, 3, 0], item.syntaxRegionList[0])
        call assert_equal(['VmenuSelectedHotkey', 3, 0, 4, 0], item.syntaxRegionList[1])
        call assert_equal(['VmenuSelect', 4, 0, 7, 0], item.syntaxRegionList[2])
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " the hotkey of inactive item should be redered
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \#{name: '&A', cmd: '', tip: '', icon: '', deactive-if: function("s:alwaysTruePredicate")}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.contextItemList[1]
        call assert_equal(['VmenuInactive', 0, 1, 3, 1], item.syntaxRegionList[0])
        call assert_equal(['VmenuInactiveHotKey', 3, 1, 4, 1], item.syntaxRegionList[1])
        call assert_equal(['VmenuInactive', 4, 1, 6, 1], item.syntaxRegionList[2])
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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

        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        let item = s:VMenuManager.__focusedWindow.getCurItem()
        call assert_equal(-1, item.descPos)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call assert_equal(['VmenuDesc', 8, 1, 9, 1], item.syntaxRegionList[1])
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("e"))
        call assert_equal("Hi    desc", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
                    \#{name: 'INACTIVE ITEM', cmd: '', deactive-if: function('s:alwaysTruePredicate')}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("G"))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " __fileterVisibleItems test
    if 1
        call assert_equal(2, s:ContextWindow.__fileterVisibleItems(s:VMenuManager.parseContextItem([
                    \#{name: 'a', cmd: 'echom 1'},
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', show-mode: ['n']}
                    \], g:VMENU#ITEM_VERSION.VMENU), #{currentMode: "n"})->len())
    endif

    " show-if test
    if 1
        call assert_equal(1, s:ContextWindow.__fileterVisibleItems(s:VMenuManager.parseContextItem([
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', show-if: function('s:alwaysTruePredicate')}
                    \], g:VMENU#ITEM_VERSION.VMENU), #{currentMode: "n"})->len())
        call assert_equal(0, s:ContextWindow.__fileterVisibleItems(s:VMenuManager.parseContextItem([
                    \#{name: 'b', cmd: 'echo 1', tip: 'tip', icon: '', show-if: function('s:alwaysFalsePredicate')}
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " deactive-if test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in normal mode', cmd: 'echo 1', tip: 'tip', icon: '', deactive-if: function("s:alwaysTruePredicate")}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList[0].isInactive({}))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " first item is inactive. should not be executed
    if 1
        let s:errorList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive item', cmd: 'echom 6', tip: 'tip', icon: '', deactive-if: function("s:alwaysTruePredicate")}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.errConsumer({ msg -> add(s:errorList, msg) })
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call assert_equal("vmenu: current item is not executable!", s:errorList[0])
    endif

    " inactive context item should not be executed by hotkey
    if 1
        let s:errorList = []
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: '', tip: '', icon: ''},
                    \#{name: '&inactive item', cmd: '', tip: '', icon: '', deactive-if: function("s:alwaysTruePredicate")}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.errConsumer({ msg -> add(s:errorList, msg) })
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("i"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " close context menu if clicked position is not in context window area
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, -1, -1)))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " inactive item should not be clicked
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: ''},
                    \#{name: 'name2', cmd: '', deactive-if: function('s:alwaysTruePredicate')},
                    \#{name: 'name2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 1)))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call assert_equal("name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " focus first valid item after opening context window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', deactive-if: function('s:alwaysTruePredicate')},
                    \#{name: '2', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 25, 0)))
        call assert_equal("   Hi2    desc  ", s:VMenuManager.__focusedWindow.getCurItem().name)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 4, 0)))
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        " left boundary
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 5, 0)))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow, 0, 0)))
        call assert_equal("sub name", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<LeftMouse>", s:createMousePosFromTopLeft(s:VMenuManager.__focusedWindow.parentVmenuWindow, 0, 1)))
        call assert_equal("sub name2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " context menu: minimal window width test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: ''},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.minWidth(10)
                    \.build()
                    \.showAtCursor()
        call assert_equal(10, s:VMenuManager.__focusedWindow.winWidth)
        call assert_equal('   1      ', s:VMenuManager.__focusedWindow.getCurItem().name)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal("1", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        call assert_equal("2", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " do nothing if sub menu are empty in top menu
    if 1
        let s:VMenuManager.__allTopMenuItemList = []
        call s:VMenuManager.initTopMenuItems('T&est-empty-sub-menu', [])
        call s:TopMenuWindow.builder()
                    \.topMenuItemList(s:VMenuManager.__allTopMenuItemList)
                    \.build()
                    \.show()
        "call s:VMenuManager.startGettingUserInput()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal("Test-empty-sub-menu", s:VMenuManager.__focusedWindow.getCurItem().name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
                    \.minWidth(10)
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'name', cmd: '', show-mode: ['v']},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'v' } })
                    \.minWidth(10)
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', subItemList: [#{name: '2', cmd: '', show-mode: ['v']}]},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.editorStatusSupplier({ -> #{currentMode: 'v' } })
                    \.minWidth(10)
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{isSep: 1},
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \#{isSep: 1},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(2, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: '', group: "g1" },
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.contextItemList->len())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))

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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    " callbackItemParam should contains origin name
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: '1', cmd: { callbackItemParam, editorStatus -> assert_equal("1" , callbackItemParam.name) }},
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal("2", s:VMenuManager.__allTopMenuItemList[0].contextItemList[1].name->trim())
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
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
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<CR>"))
        call assert_equal("1", s:VMenuManager.__allTopMenuItemList[0].contextItemList[0].name->trim())
        call assert_true(index(s:testList, "6af05433-6cc3-4fb3-9040-ec8139390709") != -1)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("j"))
        call assert_true(index(s:testList, "e65d3d2f-5e0a-4481-9b99-079ee09e9825") != -1)
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
        call s:VMenuManager.__focusedWindow.handleUserInput(s:InputEvent.new("\<ESC>"))
    endif

    call s:showErrors()
endif
