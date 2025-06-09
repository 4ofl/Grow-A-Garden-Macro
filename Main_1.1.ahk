#SingleInstance, Force
#NoEnv
SetWorkingDir %A_ScriptDir%
#WinActivateForce
SetMouseDelay, -1 
SetWinDelay, -1
SetControlDelay, -1
SetBatchLines, -1

; Globals
global webhookURL, discordUserID, PingSelected
global cycleCount := 0, currentItem := "", currentHour, currentMinute, currentSecond
global msgBoxCooldown := 0, seedAutoActive := 0, gearAutoActive := 0
global eggAutoActive := 0, safeCheckAutoActive := 0, actionQueue := [], windowIDs := []
global selectedResolution, scrollCounts_1080p, scrollCounts_1440p_100, scrollCounts_1440p_125
global gearScroll_1080p, toolScroll_1440p_100, toolScroll_1440p_125
global selectedSeedItems := [], selectedGearItems := [], selectedEggItems := []

; Resolution settings
scrollCounts_1080p := [2, 4, 6, 8, 9, 11, 13, 14, 16, 18, 20, 21, 23, 25, 26, 28, 29, 31]
scrollCounts_1440p_100 := [3, 5, 8, 10, 13, 15, 17, 20, 22, 24, 27, 30, 31, 34, 36, 38, 40, 42]
scrollCounts_1440p_125 := [3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 23, 25, 27, 29, 30, 31, 32]

gearScroll_1080p := [1, 2, 4, 6, 8, 9, 11, 13]
gearScroll_1440p_100 := [2, 3, 6, 8, 10, 13, 15, 17]
gearScroll_1440p_125 := [1, 3, 4, 6, 8, 9, 12, 12]

settingsFile := A_ScriptDir "\settings.ini"
seedItems := ["Carrot Seed", "Strawberry Seed", "Blueberry Seed", "Orange Tulip", "Tomato Seed", "Corn Seed", "Daffodil Seed", "Watermelon Seed", "Pumpkin Seed", "Apple Seed", "Bamboo Seed", "Coconut Seed", "Cactus Seed", "Dragon Fruit Seed", "Mango Seed", "Grape Seed", "Mushroom Seed", "Pepper Seed", "Cacao Seed", "Beanstalk Seed", "Ember Lily"]
gearItems := ["Watering Can", "Trowel", "Recall Wrench", "Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler", "Lightning Rod", "Master Sprinkler", "Favorite Tool", "Harvest Tool", "Friendship Pot"]
eggItems := ["Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg", "Mythical Egg", "Bug Egg"]

; Webhook functions
SendDiscordMessage(webhookURL, message) {
    FormatTime, messageTime, , hh:mm:ss tt
    fullMessage := "[" . messageTime . "] " . message

    json := "{""content"": """ . fullMessage . """}"
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")

    try {
        whr.Open("POST", webhookURL, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(json)
        whr.WaitForResponse()
        status := whr.Status
    } catch {
        return
    }
}

checkValidWebhook(url, msg := 0) {
    global webhookURL, settingsFile
    isValid := 0
    
    if (url = "" || !InStr(url, "discord.com/api")) {
        if (msg) {
            MsgBox, 0, Message, Invalid Webhook
            IniRead, savedWebhook, %settingsFile%, Main, User Webhook
            GuiControl,, webhookURL, %savedWebhook%
        }
        return false
    }

    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.Send()
        whr.WaitForResponse()
        if (whr.Status = 200 || whr.Status = 204)
            isValid := 1
    } catch {
        isValid := 0
    }

    if (msg && isValid && webhookURL != "") {
        IniWrite, %webhookURL%, %settingsFile%, Main, User Webhook
        MsgBox, 0, Message, Webhook Saved Successfully
    } else if (msg && !isValid && webhookURL != "") {
        MsgBox, 0, Message, Invalid Webhook
        IniRead, savedWebhook, %settingsFile%, Main, User Webhook
        GuiControl,, webhookURL, %savedWebhook%
    }
    return isValid
}

showPopupMessage(msgText := "nil", duration := 2000) {
    static popupID := 99
    if (msgBoxCooldown)
        return
        
    msgBoxCooldown := 1
    WinGetPos, guiX, guiY, guiW, guiH, A
    winW := 200, winH := 50
    x := guiX + (guiW - winW) // 2 - 40
    y := guiY + (guiH - winH) // 2

    Gui, %popupID%:Destroy
    Gui, %popupID%:+AlwaysOnTop -Caption +ToolWindow +Border
    Gui, %popupID%:Color, FFFFFF
    Gui, %popupID%:Font, s10 cBlack, Segoe UI
    Gui, %popupID%:Add, Text, x20 y35 w200 h50 BackgroundWhite Center cBlack, %msgText%
    Gui, %popupID%:Show, x%x% y%y% NoActivate
    SetTimer, HidePopupMessage, -%duration%
    Sleep, 2200
    msgBoxCooldown := 0
}

; Mouse functions
SafeMoveRelative(xRatio, yRatio) {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos, winX, winY, winW, winH
        MouseMove, % winX + Round(xRatio * winW), % winY + Round(yRatio * winH)
    }
}

SafeClickRelative(xRatio, yRatio) {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos, winX, winY, winW, winH
        clickX := winX + Round(xRatio * winW)
        clickY := winY + Round(yRatio * winH)
        Click, %clickX%, %clickY%
    }
}

getMouseCoord(axis) {
    CoordMode, Mouse, Screen
    MouseGetPos, x, y
    return (axis = "x") ? x : (axis = "y") ? y : ""
}

uiUniversal(order := 0, exitUi := 1, continuous := 0) {
    global FastMode, UINavToggle
    If !order
        return

    if !continuous {
        SendRaw, %UINavToggle%
        Sleep, 50
    }   

    Loop, Parse, order
        {
        if (A_LoopField = "1")
            repeatKey("Right", 1)
        else if (A_LoopField = "2")
            repeatKey("Left", 1)
        else if (A_LoopField = "3")
            repeatKey("Up", 1)
        else if (A_LoopField = "4")
            repeatKey("Down", 1)
        else if (A_LoopField = "0")
            repeatKey("Enter", 1)
        else if (A_LoopField = "5")
            Sleep, 100
        else if (A_LoopField = "6" && !FastMode)
            Sleep, 50     
    }

    if exitUi {
        Sleep, 50
        SendRaw, %UINavToggle%
    }
}

repeatKey(key := "nil", count := 0, delay := 30) {
    if (key = "nil")
        return

    Loop, %count% {
        Send {%key%}
        Sleep, %delay%
    }
}

; Color detection
quickDetectEgg(buyColor, variation := 10, x1Ratio := 0.0, y1Ratio := 0.0, x2Ratio := 1.0, y2Ratio := 1.0) {
    global selectedEggItems, currentItem, PingSelected, webhookURL, discordUserID

    static eggColorMap := { "Common Egg": "0xFFFFFF"
        , "Uncommon Egg": "0x81A7D3"
        , "Rare Egg": "0xBB5421"
        , "Legendary Egg": "0x2D78A3"
        , "Mythical Egg": "0x00CCFF"
        , "Bug Egg": "0x86FFD5" }

    Loop, 5 {
        for rarity, color in eggColorMap {
            currentItem := rarity
            isSelected := false
            for _, selected in selectedEggItems {
                if (selected = rarity) {
                    isSelected := true
                    break
                }
            }

            if simpleDetect(color, variation, 0.41, 0.32, 0.54, 0.38) {
                if isSelected {
                    quickDetect(buyColor, 0, 5, 0.4, 0.60, 0.65, 0.70, 0, 1)
                    SendDiscordMessage(webhookURL, "Bought " . currentItem . (PingSelected ? " <@" . discordUserID . ">" : ""))
                    return
                } else {
                    if simpleDetect(buyColor, variation, 0.40, 0.60, 0.65, 0.70) {
                        SendDiscordMessage(webhookURL, currentItem . " In Stock, Not Selected")
                    } else {
                        SendDiscordMessage(webhookURL, currentItem . " Not In Stock, Not Selected")
                    }
                    uiUniversal(61616056, 1, 1)
                    return
                }
            }    
        }
        Sleep, 1500
    }

    if PingSelected
        SendDiscordMessage(webhookURL, "Failed To Detect Any Egg [Error] <@" . discordUserID . ">")
    else
        SendDiscordMessage(webhookURL, "Failed To Detect Any Egg [Error]")
}

simpleDetect(colorInBGR, variation, x1Ratio := 0.0, y1Ratio := 0.0, x2Ratio := 1.0, y2Ratio := 1.0) {
    CoordMode, Pixel, Screen
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos, winX, winY, winW, winH
        x1 := winX + Round(x1Ratio * winW)
        y1 := winY + Round(y1Ratio * winH)
        x2 := winX + Round(x2Ratio * winW)
        y2 := winY + Round(y2Ratio * winH)
        
        PixelSearch, FoundX, FoundY, x1, y1, x2, y2, %colorInBGR%, variation, Fast
        return (ErrorLevel = 0)
    }
    return false
}

quickDetect(color1, color2, variation := 10, x1Ratio := 0.0, y1Ratio := 0.0, x2Ratio := 1.0, y2Ratio := 1.0, item := 1, egg := 0) {
    global currentItem, PingSelected, webhookURL, discordUserID
    CoordMode, Pixel, Screen
    stock := 0
    ping := false

    if PingSelected {
        pingItems := ["Legendary Egg", "Mythical Egg", "Godly Sprinkler", "Master Sprinkler"]
        for _, pingitem in pingItems {
            if (pingitem = currentItem) {
                ping := true
                break
            }
        }
    }

    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos, winX, winY, winW, winH
        x1 := winX + Round(x1Ratio * winW)
        y1 := winY + Round(y1Ratio * winH)
        x2 := winX + Round(x2Ratio * winW)
        y2 := winY + Round(y2Ratio * winH)

        if item {
            count := 0
            Loop {
                detected := false
                for _, c in [color1, color2] {
                    PixelSearch, FoundX, FoundY, x1, y1, x2, y2, %c%, variation, Fast RGB
                    if (ErrorLevel = 0) {
                        detected := true
                        break
                    }
                }
                if !detected
                    break

                count++
                uiUniversal("506", 0, 1)
                ; Sleep, 20
            }

            if count > 0 {
                Sleep, 250
                if ping {
                    SendDiscordMessage(webhookURL, "Bought x" . count . " " . currentItem . " <@" . discordUserID . ">")
                } else {
                    SendDiscordMessage(webhookURL, "Bought x" . count . " " . currentItem)
                }
            }
        }

        if egg {
            PixelSearch, FoundX, FoundY, x1, y1, x2, y2, %color1%, variation, Fast RGB
            if (ErrorLevel = 0) {
                stock := 1
                uiUniversal(50606, 1, 1)
                if ping {
                    SendDiscordMessage(webhookURL, "Bought " . currentItem . " <@" . discordUserID . ">")
                } else {
                    SendDiscordMessage(webhookURL, "Bought " . currentItem)
                }
            } else {
                uiUniversal(61616056, 1, 1)
                SendDiscordMessage(webhookURL, currentItem . " Not In Stock.")  
            }
        }
        Sleep, 100
    }

; Main GUI
ShowGui:
    Gui, Destroy
    Gui, +MinimizeBox -Resize
    Gui, Margin, 20, 15
    Gui, Color, 0x1E1E2E
    Gui, Font, s10 cDCD7BA, Segoe UI

    Gui, Add, Tab3, x0 y0 w540 h420 vMyTab -Theme -Wrap +Background0x1E1E2E, Info|Seeds|Gears|Eggs|Settings

    ; Info Tab
    Gui, Tab, 1
    Gui, Font, s12 cF5C2E7 Bold
    Gui, Add, Text, x30 y40 w480 h30 +0x200, INFORMATION
    Gui, Font, s10 cDCD7BA Norm

    Gui, Add, Text, x30 y85 w480, This macro automates purchasing seeds, gear, and eggs.

    Gui, Add, Text, x30 y130 w480, Before starting, please ensure the following:
    Gui, Add, Text, x50 y150 w480, - Camera mode is set to "Default (Classic)".
    Gui, Add, Text, x50 y170 w480, - "UI Navigation Toggle" is enabled in your game settings.
    Gui, Add, Text, x50 y190 w480, - "Recall Wrench" must be in inventory slot 2.

    Gui, Add, Text, x30 y210, Hotkeys:
    Gui, Add, Text, x50 y230, - F5: Start the macro
    Gui, Add, Text, x50 y250, - F7: Stop the macro

    ; Seeds Tab
    Gui, Tab, 2
    Gui, Font, s12 cF5C2E7 Bold
    Gui, Add, Text, x30 y40 w480 h30 +0x200, SEED SHOP
    Gui, Font, s10 cDCD7BA Norm
    IniRead, SelectAllSeeds, %settingsFile%, Seed, SelectAllSeeds, 0
    Gui, Add, Checkbox, x30 y75 vSelectAllSeeds gHandleSelectAll cA6E3A1, Select All Seeds

    totalSeeds := seedItems.Length()
    midSeeds := Ceil(totalSeeds / 2)
    yStart := 110
    col2X := 220

    Loop, % totalSeeds {
        if (A_Index <= midSeeds) {
            xPos := 30
            yPos := yStart + (A_Index - 1) * 26
        } else {
            xPos := col2X
            yPos := yStart + (A_Index - midSeeds - 1) * 26
        }
        
        IniRead, sVal, %settingsFile%, Seed, Item%A_Index%, 0
        Gui, Add, Checkbox, % "x" xPos " y" yPos " vSeedItem" A_Index " gHandleSelectAll cC0CAF5 " (sVal ? "Checked" : ""), % seedItems[A_Index]
    }

    ; Gears Tab
    Gui, Tab, 3
    Gui, Font, s12 cF5C2E7 Bold
    Gui, Add, Text, x30 y40 w480 h30 +0x200, GEAR SHOP
    Gui, Font, s10 cDCD7BA Norm
    IniRead, SelectAllGears, %settingsFile%, Gear, SelectAllGears, 0
    Gui, Add, Checkbox, x30 y75 vSelectAllGears gHandleSelectAll cA6E3A1, Select All Gears

    totalGears := gearItems.Length()
    midGears := Ceil(totalGears / 2)
    yStart := 110

    Loop, % totalGears {
        if (A_Index <= midGears) {
            xPos := 30
            yPos := yStart + (A_Index - 1) * 26
        } else {
            xPos := col2X
            yPos := yStart + (A_Index - midGears - 1) * 26
        }
        
        IniRead, gVal, %settingsFile%, Gear, Item%A_Index%, 0
        Gui, Add, Checkbox, % "x" xPos " y" yPos " vGearItem" A_Index " gHandleSelectAll cC0CAF5 " (gVal ? "Checked" : ""), % gearItems[A_Index]
    }

    ; Eggs Tab
    Gui, Tab, 4
    Gui, Font, s12 cF5C2E7 Bold
    Gui, Add, Text, x30 y40 w480 h30 +0x200, EGG SHOP
    Gui, Font, s10 cDCD7BA Norm
    IniRead, SelectAllEggs, %settingsFile%, Egg, SelectAllEggs, 0
    Gui, Add, Checkbox, x30 y75 vSelectAllEggs gHandleSelectAll cA6E3A1, Select All Eggs

    totalEggs := eggItems.Length()
    midEggs := Ceil(totalEggs / 2)
    yStart := 110

    Loop, % totalEggs {
        if (A_Index <= midEggs) {
            xPos := 30
            yPos := yStart + (A_Index - 1) * 26
        } else {
            xPos := col2X
            yPos := yStart + (A_Index - midEggs - 1) * 26
        }
        
        IniRead, eVal, %settingsFile%, Egg, Item%A_Index%, 0
        Gui, Add, Checkbox, % "x" xPos " y" yPos " vEggItem" A_Index " gHandleSelectAll cC0CAF5 " (eVal ? "Checked" : ""), % eggItems[A_Index]
    }

    ; Settings Tab
    Gui, Tab, 5
    Gui, Font, s12 cF5C2E7 Bold
    Gui, Add, Text, x30 y40 w480 h30 +0x200, SETTINGS
    Gui, Font, s10 cDCD7BA Norm

    ; Load Settings
    IniRead, PingSelected, %settingsFile%, Main, PingSelected, 0
    IniRead, AutoAlign, %settingsFile%, Main, AutoAlign, 0
    IniRead, FastMode, %settingsFile%, Main, FastMode, 0
    IniRead, UseAlts, %settingsFile%, Main, UseAlts, 0
    IniRead, savedWebhook, %settingsFile%, Main, User Webhook
    IniRead, savedUserID, %settingsFile%, Main, Discord UserID
    IniRead, UINavToggle, %settingsFile%, Main, UINavToggle, \

    ; Webhook URL
    Gui, Add, Text, x30 y90, Webhook URL:
    Gui, Add, Edit, x30 y110 w400 h25 vwebhookURL +Background0xFFFFFF +c000000, % savedWebhook
    Gui, Add, Button, x440 y110 w75 h25 gDisplayWebhookValidity Background0x45475A, Save

    ; Discord User ID
    Gui, Add, Text, x30 y150, Discord User ID:
    Gui, Add, Edit, x30 y170 w400 h25 vdiscordUserID +Background0xFFFFFF +c000000, % savedUserID
    Gui, Add, Button, x440 y170 w75 h25 gUpdateUserID Background0x45475A, Save

    ; Checkboxes - spaced evenly
    Gui, Add, Checkbox, % "x30 y220 vAutoAlign gUpdateSettingColor cA6E3A1 " (AutoAlign ? "Checked" : ""), Auto-Align
    Gui, Add, Checkbox, % "x30 y250 vFastMode gUpdateSettingColor cA6E3A1 " (FastMode ? "Checked" : ""), Fast Mode
    Gui, Add, Checkbox, % "x30 y280 vPingSelected gUpdateSettingColor cA6E3A1 " (PingSelected ? "Checked" : ""), Discord Pings
    Gui, Add, Checkbox, % "x30 y310 vUseAlts gUseAltsCheck cA6E3A1 " (UseAlts ? "Checked" : ""), Multi-instance Mode

    Gui, Show, w540 h390, Grow a Garden Macro
Return

; UI handlers
DisplayWebhookValidity:
    Gui, Submit, NoHide
    checkValidWebhook(webhookURL, 1)
Return

UpdateUserID:
    Gui, Submit, NoHide
    if discordUserID {
        IniWrite, %discordUserID%, %settingsFile%, Main, Discord UserID
        MsgBox, 0, Message, Discord UserID Saved
    }
Return

HandleSelectAll:
    Gui, Submit, NoHide
    if (A_GuiControl = "SelectAllSeeds") {
        Loop, % seedItems.Length()
            GuiControl,, SeedItem%A_Index%, % SelectAllSeeds
    }
    else if (A_GuiControl = "SelectAllEggs") {
        Loop, % eggItems.Length()
            GuiControl,, EggItem%A_Index%, % SelectAllEggs
    }
    else if (A_GuiControl = "SelectAllGears") {
        Loop, % gearItems.Length()
            GuiControl,, GearItem%A_Index%, % SelectAllGears
    }
    else if (RegExMatch(A_GuiControl, "^(Seed|Egg|Gear)Item\d+$", m)) {
        group := m1
        if !%A_GuiControl%
            GuiControl,, SelectAll%group%s, 0
    }
    Gosub, SaveSettings
return

UpdateSettingColor:
    Gui, Submit, NoHide
    GuiControl, % "+c" . (AutoAlign ? "90EE90" : "D3D3D3"), AutoAlign
    GuiControl, % "+c" . (FastMode ? "90EE90" : "D3D3D3"), FastMode
    GuiControl, % "+c" . (PingSelected ? "90EE90" : "D3D3D3"), PingSelected
    GuiControl, % "+c" . (UseAlts ? "90EE90" : "D3D3D3"), UseAlts
    Gosub, SaveSettings
return

UseAltsCheck:
    Gui, Submit, NoHide
    if UseAlts {
        MsgBox, 48, BE CAREFUL!!, Only use multi-instance mode if you've got alts and know what you're doing!
        showPopupMessage("Accounts detected: " CountAlts())
    }
    Gosub, UpdateSettingColor
return

HidePopupMessage:
    Gui, 99:Destroy
Return

UpdateSelectedItems:
    Gui, Submit, NoHide
    selectedSeedItems := [], selectedGearItems := [], selectedEggItems := []
    
    Loop, % seedItems.Length() {
        if SeedItem%A_Index%
            selectedSeedItems.Push(seedItems[A_Index])
    }
    Loop, % gearItems.Length() {
        if GearItem%A_Index%
            selectedGearItems.Push(gearItems[A_Index])
    }
    Loop, % eggItems.Length() {
        if EggItem%A_Index%
            selectedEggItems.Push(eggItems[A_Index])
    }
Return

; Macro core functions
StartScan:
    Gui, Submit, NoHide
    Gosub, SaveSettings
    Gosub, UpdateSelectedItems
    
    if UseAlts
        GetRobloxWindows(windowIDs)

    global lastSeedMinute := -1, lastGearMinute := -1
    global lastEggShopMinute := -1, lastSafeCheckMinute := -1

    started := 1
    SendDiscordMessage(webhookURL, "Macro started.")
    spamBuffer := 0

    Sleep, 500

    if UseAlts {
        for index, winID in windowIDs {
            WinActivate, ahk_id %winID%
            WinWaitActive, ahk_id %winID%,, 2
            if AutoAlign {
                GoSub, cameraChange
                Sleep, 100
                Gosub, zoomAlignment
                Sleep, 100
                GoSub, cameraAlignment
                Sleep, 100
                Gosub, characterAlignment
                Sleep, 100
                GoSub, cameraChange
            } else {
                Gosub, zoomAlignment
            }
        }
    } else if AutoAlign {
        GoSub, cameraChange
        Sleep, 100
        Gosub, zoomAlignment
        Sleep, 100
        GoSub, cameraAlignment
        Sleep, 100
        Gosub, characterAlignment
        Sleep, 100
        GoSub, cameraChange
    } else {
        Gosub, zoomAlignment
    }

    Sleep, 500
    SetTimer, UpdateTime, 1000

    actionQueue.Push("BuySeed")
    seedAutoActive := 1
    SetTimer, AutoBuySeed, 1000

    actionQueue.Push("BuyGear")
    gearAutoActive := 1
    SetTimer, AutoBuyGear, 1000

    actionQueue.Push("BuyEggShop")
    eggAutoActive := 1
    SetTimer, AutoBuyEggShop, 1000

    safeCheckAutoActive := 1
    SetTimer, AutoSafeCheck, 1000

    while started {
        if actionQueue.Length() {
            next := actionQueue.RemoveAt(1)
            Gosub, % next
            spamBuffer := 0
            Sleep, 500
        } else {
            mod5 := Mod(currentMinute, 5)
            rem5min := (mod5 = 0) ? 5 : 5 - mod5
            rem5sec := rem5min * 60 - currentSecond
            if (rem5sec < 0)
                rem5sec := 0
            seedMin := rem5sec // 60
            seedSec := Mod(rem5sec, 60)
            seedText := Format("{:01}:{:02}", seedMin, seedSec)

            mod30 := Mod(currentMinute, 30)
            rem30min := (mod30 = 0) ? 30 : 30 - mod30
            rem30sec := rem30min * 60 - currentSecond
            if (rem30sec < 0)
                rem30sec := 0
            eggMin := rem30sec // 60
            eggSec := Mod(rem30sec, 60)
            eggText := Format("{:01}:{:02}", eggMin, eggSec)

            if !spamBuffer {
                cycleCount++
                SendDiscordMessage(webhookURL, "[**CYCLE " . cycleCount . " COMPLETED**]")
                spamBuffer := 1
            }
            Sleep, 500
        }
    }
Return

UpdateTime:
    FormatTime, currentHour,, hh
    FormatTime, currentMinute,, mm
    FormatTime, currentSecond,, ss
    currentHour += 0, currentMinute += 0, currentSecond += 0
Return

AutoBuySeed:
    if (cycleCount > 0 && Mod(currentMinute, 5) = 0 && currentMinute != lastSeedMinute) {
        lastSeedMinute := currentMinute
        SetTimer, PushBuySeed, -2000
    }
Return

AutoBuyGear:
    if (cycleCount > 0 && Mod(currentMinute, 5) = 0 && currentMinute != lastGearMinute) {
        lastGearMinute := currentMinute
        SetTimer, PushBuyGear, -2000
    }
Return

PushBuySeed: 
    actionQueue.Push("BuySeed")
Return

PushBuyGear: 
    actionQueue.Push("BuyGear")
Return

BuySeed:
    if selectedSeedItems.Length() {
        if UseAlts {
            for index, winID in windowIDs {
                WinActivate, ahk_id %winID%
                WinWaitActive, ahk_id %winID%,, 2
                Gosub, SeedShopPath
            }
        } else {
            Gosub, SeedShopPath
        } 
    } 
Return

BuyGear:
    if selectedGearItems.Length() {
        if UseAlts {
            for index, winID in windowIDs {
                WinActivate, ahk_id %winID%
                WinWaitActive, ahk_id %winID%,, 2
                Gosub, GearShopPath
            }
        } else {
            Gosub, GearShopPath
        } 
    } 
Return

AutoBuyEggShop:
    if (cycleCount > 0 && Mod(currentMinute, 30) = 0 && currentMinute != lastEggShopMinute) {
        lastEggShopMinute := currentMinute
        SetTimer, PushBuyEggShop, -2000
    }
Return

PushBuyEggShop: 
    actionQueue.Push("BuyEggShop")
Return

BuyEggShop:
    if selectedEggItems.Length() {
        if UseAlts {
            for index, winID in windowIDs {
                WinActivate, ahk_id %winID%
                WinWaitActive, ahk_id %winID%,, 2
                Gosub, EggShopPath
            }
        } else {
            Gosub, EggShopPath
        } 
    } 
Return

AutoSafeCheck:
    if (cycleCount > 0 && Mod(currentMinute, 5) = 0 && currentMinute != lastSafeCheckMinute) {
        lastSafeCheckMinute := currentMinute
        SetTimer, PushSafeCheck, -2000
    }
Return

PushSafeCheck:
    actionQueue.Push("SafeCheck")
Return

SafeCheck:
    if UseAlts {
        for index, winID in windowIDs {
            WinActivate, ahk_id %winID%
            WinWaitActive, ahk_id %winID%,, 2
            Sleep, 500
            Send, {Enter}
            Sleep, 500
            Send, {Enter}
            Sleep, 500
        }
    } else {
        Sleep, 500
        Send, {Enter}
        Sleep, 500
        Send, {Enter}
        Sleep, 500
    } 
Return

; Alignment subroutines
cameraChange:
    Send, {Escape}
    Sleep, 500
    Send, {Tab}
    Sleep, 400
    Send {Down}
    Sleep, 100
    repeatKey("Right", 2)
    Sleep, 100
    Send {Escape}
Return

cameraAlignment:
    Click, Right, Down
    Sleep, 200
    SafeMoveRelative(0.5, 0.5)
    Sleep, 200
    MouseMove, 0, 800, 1, R
    Sleep, 200
    Click, Right, Up
Return

zoomAlignment:
    SafeMoveRelative(0.5, 0.5)
    Sleep, 100
    Loop, 40 {
        Send, {WheelUp}
        Sleep, 20
    }
    Sleep, 200
    Loop, 6 {
        Send, {WheelDown}
        Sleep, 20
    }
Return

characterAlignment:
    SendRaw, %UINavToggle%
    Sleep, 10
    repeatKey("Right", 3)
    Loop, 8 {
        Send, {Enter}
        Sleep, 10
        repeatKey("Right", 2)
        Sleep, 10
        Send, {Enter}
        Sleep, 10
        repeatKey("Left", 2)
    }
    Sleep, 10
    SendRaw, %UINavToggle%
Return

; Buying paths
EggShopPath:
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    SendDiscordMessage(webhookURL, "**[EGG CYCLE]**")
    Sleep, 200

    ; Egg 1
    Send, {w Down}
    Sleep, 1800
    Send {w Up}
    Sleep, % fastmode ? 100 : 800
    Send {e}
    Sleep, 100
    uiUniversal("61616161646", 0, 0)
    Sleep, 100
    quickDetectEgg(0x26EE26, 15, 0.41, 0.65, 0.52, 0.70)
    Sleep, 200

    ; Egg 2
    Send, {w down}
    Sleep, 200
    Send, {w up}
    Sleep, % fastmode ? 100 : 800
    Send {e}
    Sleep, 100
    uiUniversal("61616161646", 0, 0)
    Sleep, 100
    quickDetectEgg(0x26EE26, 15, 0.41, 0.65, 0.52, 0.70)
    Sleep, 200

    ; Egg 3
    Send, {w down}
    Sleep, 200
    Send, {w up}
    Sleep, % fastmode ? 100 : 800
    Send, {e}
    Sleep, 200
    uiUniversal("61616161646", 0, 0)
    Sleep, 100
    quickDetectEgg(0x26EE26, 15, 0.41, 0.65, 0.52, 0.70)
    Sleep, 200
    SendDiscordMessage(webhookURL, "**[EGGS COMPLETED]**")
Return

SeedShopPath:
    shopOpened := false
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Sleep, 100
    uiUniversal("616161616062606")
    Sleep, % FastMode ? 100 : 500
    Send {e}
    SendDiscordMessage(webhookURL, "**[SEED CYCLE]**")
    Sleep, % FastMode ? 200 : 1000

    ; Detect shop open
    Loop, 5 {
        if simpleDetect(0x00CCFF, 10, 0.54, 0.20, 0.65, 0.325) {
            shopOpened := true
            SendDiscordMessage(webhookURL, "Seed Shop Opened.")
            Break
        }
        Sleep, 2000
    }

    if !shopOpened {
        SendDiscordMessage(webhookURL, "Failed To Detect Seed Shop Opening [Error]" (PingSelected ? " <@" . discordUserID . ">" : ""))
        uiUniversal("63636362626263616161616363636262626361616161606561646056")
        Return
    }

    uiUniversal("63636361616464636363636161616464606056", 0)
    Sleep, 50
    positions := []
    Loop, % seedItems.Length() {
        if SeedItem%A_Index%
            positions.Push(A_Index)
    }
    positions.Sort()
    currentPos := 1
    for _, targetPos in positions {
        delta := targetPos - currentPos
        if (delta > 0)
            Loop, % delta
                uiUniversal("4", 0, 1)
        else if (delta < 0)
            Loop, % -delta
                uiUniversal("3", 0, 1)
        currentItem := seedItems[targetPos]
        uiUniversal("0646", 0, 1)
        Sleep, % FastMode ? 50 : 200
        quickDetect(0x26EE26, 0x1DB31D, 5, 0.4262, 0.2903, 0.6918, 0.8208)
        Sleep, 50
        uiUniversal("3606", 0, 1)
        Sleep, % FastMode ? 50 : 200
        currentPos := targetPos
        Sleep, 100
    }

    Sleep, 500
    uiUniversal("626066666606", 1, 1)
    SendDiscordMessage(webhookURL, "**[SEEDS COMPLETED]**")
Return

GearShopPath:
    shopOpened := false
    WinActivate, ahk_exe RobloxPlayerBeta.exe
    Send {2}
    Sleep, % FastMode ? 100 : 500
    SafeClickRelative(0.5, 0.5)
    Sleep, % FastMode ? 1000 : 2000
    Send {e}
    Sleep, % FastMode ? 2000 : 3000
    SafeClickRelative(0.75, 0.48)
    SendDiscordMessage(webhookURL, "**[GEAR CYCLE]**")
    Sleep, % FastMode ? 200 : 1000

    ; Detect shop open
    Loop, 5 {
        if simpleDetect(0x00CCFF, 10, 0.54, 0.20, 0.65, 0.325) {
            shopOpened := true
            SendDiscordMessage(webhookURL, "Gear Shop Opened.")
            Break
        }
        Sleep, 2000
    }

    if !shopOpened {
        SendDiscordMessage(webhookURL, "Failed To Detect Gear Shop Opening [Error]" (PingSelected ? " <@" . discordUserID . ">" : ""))
        uiUniversal("63636362626263616161616363636262626361616161606561646056")
        Return
    }

    uiUniversal("63636361616464636363636161616464606056", 0)
    Sleep, 50
    positions := []
    Loop, % gearItems.Length() {
        if GearItem%A_Index%
            positions.Push(A_Index)
    }
    positions.Sort()
    currentPos := 1
    for _, targetPos in positions {
        delta := targetPos - currentPos
        if (delta > 0)
            Loop, % delta
                uiUniversal("4", 0, 1)
        else if (delta < 0)
            Loop, % -delta
                uiUniversal("3", 0, 1)
        currentItem := gearItems[targetPos]
        uiUniversal("0646", 0, 1)
        Sleep, % FastMode ? 50 : 200
        quickDetect(0x26EE26, 0x1DB31D, 5, 0.4262, 0.2903, 0.6918, 0.8208)
        Sleep, 50
        uiUniversal("3606", 0, 1)
        Sleep, % FastMode ? 50 : 200
        currentPos := targetPos
        Sleep, 100
    }

    Sleep, 500
    uiUniversal("626066666606", 1, 1)
    SafeClickRelative(0.5, 0.5)
    SendDiscordMessage(webhookURL, "**[GEARS COMPLETED]**")
Return

; Initialization
Gosub, ShowGui
return

; Helper functions
GetRobloxWindows(ByRef idArray) {
    WinGet, rawCount, List, ahk_exe RobloxPlayerBeta.exe
    idArray := []
    Loop, % rawCount
        idArray.Push(rawCount%A_Index%)
}

CountAlts() {
    WinGet, count, List, ahk_exe RobloxPlayerBeta.exe
    return count
}

; Save settings
SaveSettings:
    Gui, Submit, NoHide
    
    ; Main settings
    IniWrite, %PingSelected%, %settingsFile%, Main, PingSelected
    IniWrite, %AutoAlign%, %settingsFile%, Main, AutoAlign
    IniWrite, %FastMode%, %settingsFile%, Main, FastMode
    IniWrite, %UseAlts%, %settingsFile%, Main, UseAlts
    IniWrite, %webhookURL%, %settingsFile%, Main, User Webhook
    IniWrite, %discordUserID%, %settingsFile%, Main, Discord UserID
    IniWrite, %UINavToggle%, %settingsFile%, Main, UINavToggle
    
    ; Seed settings
    IniWrite, %SelectAllSeeds%, %settingsFile%, Seed, SelectAllSeeds
    Loop, % seedItems.Length()
        IniWrite, % SeedItem%A_Index% ? 1 : 0, %settingsFile%, Seed, Item%A_Index%
    
    ; Gear settings
    IniWrite, %SelectAllGears%, %settingsFile%, Gear, SelectAllGears
    Loop, % gearItems.Length()
        IniWrite, % GearItem%A_Index% ? 1 : 0, %settingsFile%, Gear, Item%A_Index%
    
    ; Egg settings
    IniWrite, %SelectAllEggs%, %settingsFile%, Egg, SelectAllEggs
    Loop, % eggItems.Length()
        IniWrite, % EggItem%A_Index% ? 1 : 0, %settingsFile%, Egg, Item%A_Index%
Return

; Hotkeys
F5::Gosub, StartScan
F7::Reload

GuiClose:
    StopMacro(1)
return

StopMacro(terminate := 1) {
    global started := 0
    Gosub, SaveSettings
    if terminate
        ExitApp
}