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
let s:CLOSED_BY_EXEC = 1
let s:CLOSED_BY_ESC = 0
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
    let hotKey.offset = a:offset
    return hotKey
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

"-------------------------------------------------------------------------------
" class VmenuWindowBuilder
"-------------------------------------------------------------------------------
let s:VmenuWindowBuilder = {}
function! s:VmenuWindowBuilder.new()
    let vmenuWindowBuilder = deepcopy(s:VmenuWindowBuilder, 1)
    let vmenuWindowBuilder.__delayTime = 0
    let vmenuWindowBuilder.__parentContextWindow = {}
    let vmenuWindowBuilder.__goPreviousKey = 'k'
    let vmenuWindowBuilder.__goNextKey = 'j'
    let vmenuWindowBuilder.__closeKey = ''    "<ESC>
    let vmenuWindowBuilder.__confirmKey = ''    " <CR>
    let vmenuWindowBuilder.__goBottomKey = 'G'
    let vmenuWindowBuilder.__x = 0
    let vmenuWindowBuilder.__y = 0
    let vmenuWindowBuilder.__traceId = ''
    let vmenuWindowBuilder.__errConsumer = function("s:printErr")
    return vmenuWindowBuilder
endfunction
function! s:VmenuWindowBuilder.position(position)
    let self.__x = a:position[0]
    let self.__y = a:position[1]
    return self
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
    let vmenuWindow.__goPreviousKey = 'l'
    let vmenuWindow.__goNextKey = 'h'
    let vmenuWindow.__closeKey = ''
    let vmenuWindow.__confirmKey = ''
    let vmenuWindow.__delayTime = 0
    let vmenuWindow.__goBottomKey = ''
    let vmenuWindow.__traceId = ''
    let vmenuWindow.__keyMap = {}
    let vmenuWindow.__errConsumer = function("s:printErr")
    return vmenuWindow
endfunction
function! s:VmenuWindow.focusNext()
endfunction
function! s:VmenuWindow.focusPrev()
endfunction
function! s:VmenuWindow.focusItemByIndex(index)
endfunction
function! s:VmenuWindow.focusBottom()
endfunction
" enter focused item. open sub menu or execute cmd
function! s:VmenuWindow.enter()
endfunction
function! s:VmenuWindow.executeByHotKey(code)
    let hotKeyIdx = indexof(self.hotKeyList, {i, v -> v.code == a:code})
    if hotKeyIdx != -1
        call self.focusItemByIndex(self.hotKeyList[hotKeyIdx].offset)
        call self.enter()
    endif
endfunction
function! s:VmenuWindow.close(closedByExec=s:CLOSED_BY_ESC)
    call self.quickuiWindow.close()
    let self.isOpen = 0
    if has_key(self, 'parentVmenuWindow') && !empty(self.parentVmenuWindow)
        call self.parentVmenuWindow.__onSubMenuClose(a:closedByExec)
    endif

    " root window, stop getting user input
    if !has_key(self, 'parentVmenuWindow') || empty(self.parentVmenuWindow)
        call s:VMenuManager.stopListen()
    endif
endfunction

function! s:VmenuWindow.__onSubMenuClose(closeCode)
    if a:closeCode == s:CLOSED_BY_EXEC
        call self.close(s:CLOSED_BY_EXEC)
    else
        call s:VMenuManager.setFocusedWindow(self)
        " this will refresh tips in statusline
        call self.focusItemByIndex(self.__curItemIndex)
    endif
endfunction

function! s:VmenuWindow.handleKeyStroke(code, doAfterKeyStroke={ contextWindow -> '' })
    if self.__delayTime != 0
        execute self.__delayTime .. 'sleep'
    endif

    if has_key(self.__keyMap, nr2char(a:code))
        call self.__keyMap[nr2char(a:code)]()
        return
    else
        " do nothing
    endif

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
    let contextWindowBuilder.__closeKey = ''
    let contextWindowBuilder.__confirmKey = ''    " <CR>
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
    let contextWindow.contextItemList = s:ContextWindow.__fileterVisibleItems(a:contextWindowBuilder.__contextItemList, s:VMenuManager.getGlobalStautus())
    let contextWindow.contextItemList = s:ItemParser.__fillNameToSameLength(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__concatenateShortKey(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__fillNameToSameLength(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__addIcon(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__addPaddingInContextMenu(contextWindow.contextItemList)
    let contextWindow.contextItemList = s:ItemParser.__renderSeparatorLine(contextWindow.contextItemList)
    let contextWindow.quickuiWindow = quickui#window#new()
    let contextWindow.winId = rand(srand())
    let contextWindow.hotKeyList = []
    let contextWindow.winWidth = strcharlen(contextWindow.contextItemList[0].name)
    let contextWindow.x = a:contextWindowBuilder.__x " column number
    let contextWindow.y = a:contextWindowBuilder.__y " line number
    let contextWindow.__delayTime = a:contextWindowBuilder.__delayTime
    for i in range(len(contextWindow.contextItemList))
        if contextWindow.contextItemList[i].hotKey != ''
            call extend(contextWindow.hotKeyList, [s:HotKey.new(contextWindow.contextItemList[i].hotKey->tolower(), i)])
        endif
    endfor

    let contextWindow.__curItemIndex = 0
    let contextWindow.__curItem = get(contextWindow.contextItemList, 0, {}) " currently selected context item
    let contextWindow.__subContextWindowOpen = 0
    let contextWindow.__traceId = a:contextWindowBuilder.__traceId
    let contextWindow.__errConsumer = a:contextWindowBuilder.__errConsumer
    let contextWindow.isOpen = 0
    let contextWindow.parentVmenuWindow = a:contextWindowBuilder.__parentContextWindow
    let contextWindow.__logger = s:Log.new(contextWindow)
    call contextWindow.__logger.info(printf("new ContextWindow created, winId: %s", contextWindow.winId))

    let keyMap = {}
    let keyMap[a:contextWindowBuilder.__closeKey]      = function(contextWindow.close,       [], contextWindow)
    let keyMap[a:contextWindowBuilder.__goNextKey]     = function(contextWindow.focusNext,   [], contextWindow)
    let keyMap[a:contextWindowBuilder.__goPreviousKey] = function(contextWindow.focusPrev,   [], contextWindow)
    let keyMap[a:contextWindowBuilder.__goBottomKey]   = function(contextWindow.focusBottom, [], contextWindow)
    let keyMap[a:contextWindowBuilder.__confirmKey]    = function(contextWindow.enter,     [], contextWindow)
    for hotKey in contextWindow.hotKeyList
        let keyMap[hotKey['keyChar']] = function(contextWindow.executeByHotKey, [hotKey.code], contextWindow)
    endfor

    let contextWindow.__keyMap = keyMap
    return contextWindow
endfunction
" globalStatus: class GlobalStautus
function! s:ContextWindow.__fileterVisibleItems(itemList, globalStatus)
    let activeItems = []

    for contextItem in a:itemList
        if get(contextItem, 'isVisible')(a:globalStatus) == 1
            call add(activeItems, deepcopy(contextItem, 1))
        endif
    endfor

    return activeItems
endfunction

function! s:ContextWindow.showAt(x, y)
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
    call self.focusItemByIndex(self.__curItemIndex)
    call self.__logger.info(printf("ContextWindow opened at x:%s, y:%s, winId: %s", self.x, self.y, self.winId))
endfunction
function! s:ContextWindow.showAtCursor()
    let cursorPos = quickui#core#around_cursor(self.winWidth, self.contextItemList->len())
    call self.showAt(cursorPos[1], cursorPos[0])
endfunction
function! s:ContextWindow.focusItemByIndex(index)
    let self.__curItemIndex = a:index
    let self.__curItem = self.contextItemList[a:index]
    call self.__renderHighlight(a:index)
    call self.__triggerStatuslineRefresh()
    call self.__echoTipsIfEnabled()
    redraw
endfunction
function! s:ContextWindow.__triggerStatuslineRefresh()
    if has('nvim') == 1
lua << EOF
    if package.loaded['lualine'] then
        require('lualine').refresh()
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
    return self.__curItem.tip
endfunction
function! s:ContextWindow.focusNext()
    let idx = self.__curItemIndex + 1
    while idx < self.contextItemList->len() && !self.isExecutable(idx)
        let idx += 1
    endwhile
    if idx < self.contextItemList->len()
        call self.focusItemByIndex(idx)
    else
        " no valid next item. do nothing
    endif
endfunction
function! s:ContextWindow.focusPrev()
    let idx = self.__curItemIndex - 1
    while idx >= 0 && !self.isExecutable(idx)
        let idx -= 1
    endwhile
    if idx >= 0
        call self.focusItemByIndex(idx)
    else
        " no valid previous item. do nothing
    endif
endfunction
function! s:ContextWindow.focusBottom()
    call self.focusItemByIndex(len(self.contextItemList)-1)
endfunction
function! s:ContextWindow.isExecutable(idx)
    return self.contextItemList[a:idx].isSep == 0 && self.contextItemList[a:idx].isInactive(s:VMenuManager.getGlobalStautus()) == 0
endfunction

function! s:ContextWindow.enter()
    if !self.isExecutable(self.__curItemIndex)
        call self.__errConsumer("vmenu: current item is not executable!")
        return
    endif

    let subItemList = self.contextItemList[self.__curItemIndex].subItemList
    if (!subItemList->empty())
        let subContextWindow = s:ContextWindow.builder()
                    \.contextItemList(subItemList)
                    \.parentVmenuWindow(self)
                    \.build()
        let x = self.x + self.winWidth
        let y = self.y + self.__curItemIndex

        " if there are insufficient space for sub context window at right side, then open at left side
        if self.x + self.winWidth + subContextWindow.winWidth > &columns
            let x = self.x - subContextWindow.winWidth
        endif
        call subContextWindow.showAt(x, y)
        let self.__subContextWindowOpen = 1
    else
        let cmd = self.contextItemList[self.__curItemIndex].cmd
        if strcharlen(cmd) > 0
            call self.close(s:CLOSED_BY_EXEC)

            call execute(cmd)
            "call self.quickuiWindow.execute(cmd)
            call self.__logger.info(printf("winId: %s, execute cmd: %s", self.winId, cmd))
        endif
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
        if self.contextItemList[index].isInactive(s:VMenuManager.getGlobalStautus()) == 1
            call win.syntax_region("VmenuInactive", 0, index, win.opts.w, index)
            continue
        endif

        " hot key
        call win.syntax_region("VmenuHotkey1", self.contextItemList[index].hotKeyPos, index, self.contextItemList[index].hotKeyPos + 1, index)

        " seperator line
        if self.contextItemList[index].isSep == 1
            call win.syntax_region("VmenuSepLine", 0, index, win.opts.w, index)
        endif

        " desc
        if self.contextItemList[index].descPos != -1
            call win.syntax_region("VmenuDesc", self.contextItemList[index].descPos, index, self.contextItemList[index].descPos + self.contextItemList[index].descWidth, index)
        endif
    endfor

    " [hilight, start column number, start line number, end column number, end line number]
    let focusedLineSyntaxList = []
    let item = self.contextItemList[a:offset]
    if self.contextItemList[a:offset].hotKeyPos == -1
        call add(focusedLineSyntaxList, ["VmenuSelect", 0, a:offset, win.opts.w, a:offset])
    else
        call add(focusedLineSyntaxList, ["VmenuSelect", 0, a:offset, item.hotKeyPos, a:offset])
        call add(focusedLineSyntaxList, ["VmenuSelectedHotkey", item.hotKeyPos, a:offset, item.hotKeyPos+1, a:offset])
        call add(focusedLineSyntaxList, ["VmenuSelect", item.hotKeyPos+1, a:offset, win.opts.w, a:offset])
    endif
    let item.focusedLineSyntaxList = deepcopy(focusedLineSyntaxList, 1)
    for syntax in focusedLineSyntaxList
        call win.syntax_region(syntax[0], syntax[1], syntax[2], syntax[3], syntax[4])
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
    let contextItem.tip             = get(a:dict, 'tip', '')
    let contextItem.name            = get(a:dict, 'name', '')
    let contextItem.hotKey          = get(a:dict, 'hotKey', '')
    let contextItem.hotKeyPos       = get(a:dict, 'hotKeyPos', -1)
    let contextItem.isVisible  = get(a:dict, 'isVisible')   " GlobalStautus class -> 0/1
    let contextItem.isInactive = get(a:dict, 'isInactive')   " GlobalStautus class -> 0/1
    let contextItem.subItemList     = get(a:dict, 'subItemList', [])    " ContextItem[]
    let contextItem.isSep           = get(a:dict, 'isSep', 0)
    let contextItem.descPos         = get(a:dict, 'descPos', -1)
    let contextItem.descWidth       = get(a:dict, 'descWidth', 0)
    let contextItem.focusedLineSyntaxList       = []
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
    let topMenuWindowBuilder.__closeKey = ''
    let topMenuWindowBuilder.__confirmKey = ''    " <CR>
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
    let topMenuWindow.quickuiWindow = quickui#window#new()
    let topMenuWindow.winId = rand(srand())
    let topMenuWindow.hotKeyList = []
    let topMenuWindow.winWidth = &columns
    for i in range(len(topMenuWindow.topMenuItemList))
        if topMenuWindow.topMenuItemList[i].hotKey != ''
            call extend(topMenuWindow.hotKeyList, [s:HotKey.new(topMenuWindow.topMenuItemList[i].hotKey->tolower(), i)])
        endif
    endfor

    let topMenuWindow.__curItemIndex = 0
    let topMenuWindow.__curItem = get(topMenuWindow.topMenuItemList, 0, {}) " currently selected context item
    let topMenuWindow.__subContextWindowOpen = 0
    let topMenuWindow.__padding = 2 " spaces added on the left and right side for every item
    let topMenuWindow.__delayTime = a:topMenuWindowBuilder.__delayTime
    let topMenuWindow.__traceId = a:topMenuWindowBuilder.__traceId
    let topMenuWindow.isOpen = 0
    let topMenuWindow.__logger = s:Log.new(topMenuWindow)
    call topMenuWindow.__logger.info(printf("new TopMenuWindow created, winId: %s", topMenuWindow.winId))

    let keyMap = {}
    let keyMap[a:topMenuWindowBuilder.__closeKey]      = function(topMenuWindow.close,       [], topMenuWindow)
    let keyMap[a:topMenuWindowBuilder.__goNextKey]     = function(topMenuWindow.focusNext,   [], topMenuWindow)
    let keyMap[a:topMenuWindowBuilder.__goPreviousKey] = function(topMenuWindow.focusPrev,   [], topMenuWindow)
    let keyMap[a:topMenuWindowBuilder.__goBottomKey]   = function(topMenuWindow.focusBottom, [], topMenuWindow)
    let keyMap[a:topMenuWindowBuilder.__confirmKey]    = function(topMenuWindow.enter,     [], topMenuWindow)
    for hotKey in topMenuWindow.hotKeyList
        let keyMap[hotKey['keyChar']] = function(topMenuWindow.executeByHotKey, [hotKey.code], topMenuWindow)
    endfor

    let topMenuWindow.__keyMap = keyMap
    return topMenuWindow
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
    let self.__curItem = self.topMenuItemList[self.__curItemIndex]
    call self.__renderHighlight(self.__curItemIndex)
    redraw
endfunction
function! s:TopMenuWindow.getFocusedItemTips()
    return ''
endfunction
function! s:TopMenuWindow.focusNext()
    let idx = self.__curItemIndex + 1
    if idx < self.topMenuItemList->len()
        call self.focusItemByIndex(idx)
    else
        " no valid next item. do nothing
    endif
endfunction
function! s:TopMenuWindow.focusPrev()
    let idx = self.__curItemIndex - 1
    if idx >= 0
        call self.focusItemByIndex(idx)
    else
        " no valid previous item. do nothing
    endif
endfunction
function! s:TopMenuWindow.enter()
    let subItemList = self.topMenuItemList[self.__curItemIndex].contextItemList
    if (!subItemList->empty())
        let x = self.__getStartColumnNrByIndex(self.__curItemIndex)
        let y = 1
        let subContextWindow = s:ContextWindow.builder()
                    \.contextItemList(subItemList)
                    \.parentVmenuWindow(self)
                    \.build()
                    \.showAt(x, y)
        let self.__subContextWindowOpen = 1
    else
        let cmd = self.topMenuItemList[self.__curItemIndex].cmd
        if strcharlen(cmd) > 0
            exec cmd
            call self.__logger.info(printf("winId: %s, execute cmd: %s", self.winId, cmd))
        endif
        "call self.quickuiWindow.execute(cmd)

        call self.close(1)
    endif
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

    let focusedLineSyntaxList = []
    let item = self.topMenuItemList[a:offset]
    if self.topMenuItemList[a:offset].hotKeyPos == -1
        let startX = self.__getStartColumnNrByIndex(self.__curItemIndex)
        call add(focusedLineSyntaxList, ['VmenuSelect', startX, 0, startX + strcharlen(self.__curItem.name), 0])
    else
        let startX = self.__getStartColumnNrByIndex(self.__curItemIndex) " start position in whole top menu window
        let endX = startX + item.hotKeyPos
        call add(focusedLineSyntaxList, ['VmenuSelect', startX, 0, endX, 0])
        call add(focusedLineSyntaxList, ["VmenuSelectedHotkey", endX, 0, endX+1, 0])
        call add(focusedLineSyntaxList, ["VmenuSelect", endX+1, 0, startX+strcharlen(item.name), 0])
    endif
    let item.focusedLineSyntaxList = deepcopy(focusedLineSyntaxList, 1)
    for syntax in focusedLineSyntaxList
        call win.syntax_region(syntax[0], syntax[1], syntax[2], syntax[3], syntax[4])
    endfor
    call win.syntax_end()
endfunction


"-------------------------------------------------------------------------------
" class GlobalStautus
"-------------------------------------------------------------------------------
let s:GlobalStautus = {}
" WARNNING: There are some bugs in detecting visual mode, so it is not recomended to use currently.
let s:GlobalStautus.currentMode = ''
let s:GlobalStautus.currentFileType = ''


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

    let dropMenu = s:VMenuManager.parseContextItem(a:userItemList)
    let topMenuItem = s:TopMenuItem.new(topItem.name, topItem.hotKey, topItem.hotKeyPos, dropMenu)
    call add(s:VMenuManager.__allTopMenuItemList, topMenuItem)
    return topMenuItem
endfunction

function! s:VMenuManager.startGettingUserInput()
    let self.__keepGettingInput = 1
    while self.__keepGettingInput
        let code = getchar()
        call self.__focusedWindow.handleKeyStroke(code)
    endwhile
endfunction

function! s:VMenuManager.stopListen()
    let self.__keepGettingInput = 0
endfunction

 " focused context window will receive and handle input
function! s:VMenuManager.setFocusedWindow(contextWindow)
    let self.__focusedWindow = a:contextWindow
endfunction


function! s:getSelectedText()
    let origin = getreg('z')
    call execute('norm gv"zy')
    let selectedText = getreg('z')
    call setreg('z', origin)
endfunction
" TODO: complete this
function! s:VMenuManager.getGlobalStautus()
    let s:GlobalStautus.currentMode = mode()
    let s:GlobalStautus.currentFileType = &ft
    "TODO: only execute when needed
    "let s:GlobalStautus.selectedText = s:getSelectedText()
    return s:GlobalStautus
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
    let cmd       = get(a:userItem, 'cmd', '')
    let tip       = get(a:userItem, 'tip', '')
    let icon      = get(a:userItem, 'icon', '')
    let shortKey  = get(a:userItem, 'shortKey', '')
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
                \cmd: cmd,
                \tip: tip,
                \shortKey: shortKey,
                \hotKey: hotKey,
                \hotKeyPos: hotKeyPos,
                \isVisible: VisiblePredicate,
                \isInactive: DeactivePredicate,
                \subItemList: subItemList,
                \isSep: isSep
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
                \isSep: isSep}
                \)
endfunction

" TODO: should be inclucded in context window class
function! s:ItemParser.__fillNameToSameLength(contextItemList)
    let workingContextItemList = deepcopy(a:contextItemList, 1)
    let maxNameLen = reduce(workingContextItemList, { acc, val -> max([acc, strcharlen(val.name)]) }, 0)
    for contextItem in workingContextItemList
        if strcharlen(contextItem.name) < maxNameLen
            let contextItem.name = contextItem.name .. repeat(' ', maxNameLen - strcharlen(contextItem.name))
        endif
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
        let padding = '  '
        let contextItem.name = padding .. contextItem.name .. '  '
        let contextItem.descPos = strcharlen(contextItem.shortKey) > 0 ?
                    \ contextItem.descPos + strcharlen(padding) : -1 " adjust desc pos
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
        let s = contextItem.icon .. repeat(' ', maxIconLen-strcharlen(contextItem.icon)) .. ' '
        let contextItem.name = s .. contextItem.name
        let contextItem.descPos = contextItem.descPos + strcharlen(s)  " adjust desc pos
        let contextItem.hotKeyPos = contextItem.hotKeyPos == -1 ? -1 : contextItem.hotKeyPos + strcharlen(s)
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

let s:secondMenuMap = {}
function! s:extractSubMenuOfExpand(callId, quickuiItem)
    let s:secondMenuMap = {}
    let s:secondMenuMap[a:callId] = deepcopy(a:quickuiItem)
endfunction

function! s:createModePredicate(modes)
    return { globalStatus -> index(a:modes, globalStatus['currentMode']) != -1}
endfunction

function! s:createFileTypePredicate(fileTypes)
    return { globalStatus -> index(a:fileTypes, globalStatus['currentFileType']) != -1}
endfunction

function! s:alwaysFalsePredicate(globalStatus)
    return 0
endfunction

function! s:alwaysTruePredicate(globalStatus)
    return 1
endfunction


" content: parsed context item list
function! vmenu#openContextWindow(content, opts)
    call s:ContextWindow.builder()
                \.contextItemList(a:content)
                \.build()
                \.showAtCursor()
    call s:VMenuManager.startGettingUserInput()
endfunction
" userItemList: quickui context menu or vmenu context menu
" return parsed context item list
function! vmenu#parse_context(userItemList, itemVersion=g:VMENU#ITEM_VERSION.QUICKUI)
    return s:VMenuManager.parseContextItem(a:userItemList, a:itemVersion)
endfunction
function! vmenu#installTopMenu(name, userTopMenu)
    call s:VMenuManager.initTopMenuItems(a:name ,a:userTopMenu)
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
        echom printf("TRACEID:[%s] %s", self.vmenuWindow.__traceId, a:msg)
    endif
endfunction
function! s:Log.simpleLog(msg)
    if s:enable_log == 1
        echom a:msg
    endif
endfunction

"-------------------------------------------------------------------------------
" utils
"-------------------------------------------------------------------------------
function! s:printErr(msg)
    echohl WarningMsg | echo a:msg | echohl None
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
    let opts.w = 150
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))

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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        let contextItem = s:ItemParser.parseVMenuItem(#{name: '&Hi', cmd: 'echom 6', tip: 'tip', icon: 'icon', show-mode: ['n', 'v']})
        call assert_equal("Hi", contextItem.name, "name parse failed!")
        call assert_equal(0, contextItem.hotKeyPos, "hotKeyPos parse failed!")
        call assert_equal('H', contextItem.hotKey, "hotKey parse failed!")
        call assert_equal('echom 6', contextItem.cmd, "cmd parse failed!")
        call assert_equal('icon', contextItem.icon, "icon parse failed!")
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
    endif

    " when cmd is executed, close all context window
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["first menu", 'call quickui#context#expand([["second menu", "echo 1"]])']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''), { contextWindow -> assert_equal(1, contextWindow.isOpen) })
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''), { contextWindow -> assert_true(contextWindow.isOpen == 0 && contextWindow.parentVmenuWindow.isOpen == 0) })
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('h'), { contextWindow -> assert_equal(0, contextWindow.isOpen) })
        call assert_true(index(s:testList, msg) != -1)
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('f'), { contextWindow -> assert_true(contextWindow.isOpen == 1 && contextWindow.__subContextWindowOpen == 1) })
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('s'), { contextWindow -> assert_true(contextWindow.isOpen == 0 && contextWindow.__subContextWindowOpen == 0) })
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

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
        call assert_equal('second', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
        call assert_equal('first', vmenu#itemTips())

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        call assert_equal('test help', vmenu#itemTips())

        " after close, tip should be cleaned
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        call assert_equal("b", s:VMenuManager.__focusedWindow.__curItem.name->trim())

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('k'))
        call assert_equal("a", s:VMenuManager.__focusedWindow.__curItem.name->trim())
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        call assert_equal("a", s:VMenuManager.__focusedWindow.__curItem.name->trim())

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        call assert_equal("c", s:VMenuManager.__focusedWindow.__curItem.name->trim())
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('k'))
        call assert_equal("a", s:VMenuManager.__focusedWindow.__curItem.name->trim())

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
    endif

    " show-ft test
    if 1
        call assert_equal('n', s:VMenuManager.getGlobalStautus().currentMode)
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in vim file', cmd: 'echo 1', tip: 'tip', icon: '', show-ft: ['vim']}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.__curItem.isVisible(#{currentFileType: 'vim'}))
        call assert_equal(0, s:VMenuManager.__focusedWindow.__curItem.isVisible(#{currentFileType: 'lua'}))
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call assert_equal(-1, s:VMenuManager.__focusedWindow.__curItem.hotKeyPos)
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal("H", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))

        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \ #{text: "c", cmd: "", help: '', icon:'󰆏'},
                    \["&Hi", '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal("H", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
    endif

    " focusedLineSyntaxList test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["Hi", ''],
                    \]))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal(1, item.focusedLineSyntaxList->len())
        call assert_equal(['VmenuSelect', 0, 0, 7, 0], item.focusedLineSyntaxList[0])
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
    endif

    " focusedLineSyntaxList test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \["&Hi", ''],
                    \]))
                    \.build()
                    \.showAtCursor()
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal(['VmenuSelect', 0, 0, 3, 0], item.focusedLineSyntaxList[0])
        call assert_equal(['VmenuSelectedHotkey', 3, 0, 4, 0], item.focusedLineSyntaxList[1])
        call assert_equal(['VmenuSelect', 4, 0, 7, 0], item.focusedLineSyntaxList[2])
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal("desc", item.name[item.descPos:item.descPos+item.descWidth-1])

        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('j'))
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal(-1, item.descPos)
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        let item = s:VMenuManager.__focusedWindow.__curItem
        call assert_equal(3, item.hotKeyPos)
        call assert_equal("e", item.name[item.hotKeyPos])
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
                    \["1", ''],
                    \["2", '']
                    \]))
                    \.build()
                    \.showAtCursor()
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr('G'))
        call assert_equal("2", s:VMenuManager.__focusedWindow.__curItem.name->trim())
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call assert_equal(1, s:VMenuManager.__focusedWindow.__curItem.isInactive(#{currentMode: 'n'}))
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call assert_equal(1, s:VMenuManager.__focusedWindow.__curItem.isInactive(#{currentFileType: 'vim'}))
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call assert_equal(0, s:VMenuManager.__focusedWindow.__curItem.isInactive(#{currentFileType: 'vim'}))
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
    endif

    " deactive-if test
    if 1
        call s:ContextWindow.builder()
                    \.contextItemList(s:VMenuManager.parseContextItem([
                    \#{name: 'inactive in normal mode', cmd: 'echo 1', tip: 'tip', icon: '', deactive-if: function("s:alwaysTruePredicate")}
                    \], g:VMENU#ITEM_VERSION.VMENU))
                    \.build()
                    \.showAtCursor()
        call assert_equal(1, s:VMenuManager.__focusedWindow.__curItem.isInactive({}))
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
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
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
        call assert_equal(1, s:VMenuManager.__focusedWindow.isOpen == 1)    " keep opening
        call s:VMenuManager.__focusedWindow.handleKeyStroke(char2nr(''))
        call assert_equal("vmenu: current item is not executable!", s:errorList[0])
    endif

    call s:showErrors()
endif

"call s:ContextWindow.builder()
        "\.contextItemList(s:VMenuManager.parseContextItem([
        "\#{name: '0123456789', cmd: 'echom 1', tip: 'tip', icon: '', subItemList: [#{name: 'sub name', cmd: 'echom 1.1', tip: 'tip2', icon: ''}]},
        "\], g:VMENU#ITEM_VERSION.VMENU))
        "\.build()
        "\.showAtCursor()
"call s:VMenuManager.startGettingUserInput()
