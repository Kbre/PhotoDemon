Attribute VB_Name = "Interface"
'***************************************************************************
'Miscellaneous Functions Related to the User Interface
'Copyright �2001-2013 by Tanner Helland
'Created: 6/12/01
'Last updated: 21/August/13
'Last update: Merged the old toolbar module into this one, and renamed it to better fit the program's current state.
'
'Miscellaneous routines related to rendering PhotoDemon interface elements.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://www.tannerhelland.com/photodemon/#license
'
'***************************************************************************


Option Explicit

'Experimental subclassing to fix background color problems
' Many thanks to pro VB programmer LaVolpe for this workaround for themed controls not respecting their owner's backcolor properly.
Private Declare Function SendMessage Lib "user32.dll" Alias "SendMessageA" (ByVal hWnd As Long, ByVal wMsg As Long, ByVal wParam As Long, ByRef lParam As Any) As Long
Private Declare Function SetWindowLong Lib "user32.dll" Alias "SetWindowLongA" (ByVal hWnd As Long, ByVal nIndex As Long, ByVal dwNewLong As Long) As Long
Private Declare Function CallWindowProc Lib "user32.dll" Alias "CallWindowProcA" (ByVal lpPrevWndFunc As Long, ByVal hWnd As Long, ByVal Msg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
Private Declare Function GetWindowLong Lib "user32.dll" Alias "GetWindowLongA" (ByVal hWnd As Long, ByVal nIndex As Long) As Long
Private Declare Function GetProp Lib "user32.dll" Alias "GetPropA" (ByVal hWnd As Long, ByVal lpString As String) As Long
Private Declare Function SetProp Lib "user32.dll" Alias "SetPropA" (ByVal hWnd As Long, ByVal lpString As String, ByVal hData As Long) As Long
Private Declare Function DefWindowProc Lib "user32.dll" Alias "DefWindowProcA" (ByVal hWnd As Long, ByVal wMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
Private Const WM_PRINTCLIENT As Long = &H318
Private Const WM_PAINT As Long = &HF&
Private Const GWL_WNDPROC As Long = -4
Private Const WM_DESTROY As Long = &H2

'Used to measure the expected length of a string
Private Declare Function GetTextExtentPoint32 Lib "gdi32" Alias "GetTextExtentPoint32A" (ByVal hDC As Long, ByVal lpsz As String, ByVal cbString As Long, ByRef lpSize As POINTAPI) As Long

'These constants are used to toggle visibility of display elements.
Public Const VISIBILITY_TOGGLE As Long = 0
Public Const VISIBILITY_FORCEDISPLAY As Long = 1
Public Const VISIBILITY_FORCEHIDE As Long = 2

'These values are used to remember the user's current font smoothing setting.  We try to be polite and restore
' the original setting when the application terminates.
Private Declare Function SystemParametersInfo Lib "user32" Alias "SystemParametersInfoA" (ByVal uiAction As Long, ByVal uiParam As Long, ByRef pvParam As Long, ByVal fWinIni As Long) As Long

Private Const SPI_GETFONTSMOOTHING As Long = &H4A
Private Const SPI_SETFONTSMOOTHING As Long = &H4B
Private Const SPI_GETFONTSMOOTHINGTYPE As Long = &H200A
Private Const SPI_SETFONTSMOOTHINGTYPE As Long = &H200B
Private Const SmoothingClearType As Long = &H2
Private Const SmoothingStandardType As Long = &H1
Private Const SmoothingNone As Long = &H0

'Constants that define single meta-level actions that require certain controls to be en/disabled.  These are passed to tInit, below.
'(Note: these constants should eventually be converted to an Enum)
Public Enum metaInitializer
     tOpen = 0
     tSave = 1
     tSaveAs = 2
     tCopy = 3
     tPaste = 4
     tUndo = 5
     tImageOps = 6
     tFilter = 7
     tRedo = 8
     'tHistogram = 9
     tMacro = 10
     tEdit = 11
     tRepeatLast = 12
     tSelection = 13
     tSelectionTransform = 14
     tImgMode32bpp = 15
     tMetadata = 16
     tGPSMetadata = 17
End Enum

'If PhotoDemon enabled font smoothing where there was none previously, it will restore the original setting upon exit.  This variable
' can contain the following values:
' 0: did not have to change smoothing, as ClearType is already enabled
' 1: had to change smoothing type from Standard to ClearType
' 2: had to turn on smoothing, as it was originally turned off
Private hadToChangeSmoothing As Long


'metaToggle enables or disables a swath of controls related to a simple keyword (e.g. "Undo", which affects multiple menu items
' and toolbox buttons)
Public Sub metaToggle(ByVal metaItem As metaInitializer, ByVal newState As Boolean)
    
    Dim i As Long
    
    Select Case metaItem
        
        'Open (left-hand panel button AND menu item)
        Case tOpen
            If FormMain.MnuOpen.Enabled <> newState Then
                FormMain.cmdOpen.Enabled = newState
                FormMain.MnuOpen.Enabled = newState
            End If
            
        'Save (left-hand panel button AND menu item)
        Case tSave
            If FormMain.MnuSave.Enabled <> newState Then
                FormMain.cmdSave.Enabled = newState
                FormMain.MnuSave.Enabled = newState
            End If
            
        'Save As (menu item only)
        Case tSaveAs
            If FormMain.MnuSaveAs.Enabled <> newState Then
                FormMain.cmdSaveAs.Enabled = newState
                FormMain.MnuSaveAs.Enabled = newState
            End If
        
        'Copy (menu item only)
        Case tCopy
            If FormMain.MnuCopy.Enabled <> newState Then FormMain.MnuCopy.Enabled = newState
        
        'Paste (menu item only)
        Case tPaste
            If FormMain.MnuPaste.Enabled <> newState Then FormMain.MnuPaste.Enabled = newState
        
        'Undo (left-hand panel button AND menu item)
        Case tUndo
            If FormMain.MnuUndo.Enabled <> newState Then
                FormMain.cmdUndo.Enabled = newState
                FormMain.MnuUndo.Enabled = newState
            End If
            'If Undo is being enabled, change the text to match the relevant action that created this Undo file
            If newState Then
                FormMain.cmdUndo.ToolTip = pdImages(CurrentImage).getUndoProcessID
                FormMain.MnuUndo.Caption = g_Language.TranslateMessage("Undo:") & " " & pdImages(CurrentImage).getUndoProcessID
                ResetMenuIcons
            Else
                FormMain.cmdUndo.ToolTip = ""
                FormMain.MnuUndo.Caption = g_Language.TranslateMessage("Undo")
                ResetMenuIcons
            End If
            
        'ImageOps is all Image-related menu items; it enables/disables the Image, Select, Color, View (most items), and Print menus
        Case tImageOps
            If FormMain.MnuImageTop.Enabled <> newState Then
                FormMain.MnuImageTop.Enabled = newState
                'Use this same command to disable other menus
                FormMain.MnuPrint.Enabled = newState
                FormMain.MnuFitOnScreen.Enabled = newState
                FormMain.MnuFitWindowToImage.Enabled = newState
                FormMain.MnuZoomIn.Enabled = newState
                FormMain.MnuZoomOut.Enabled = newState
                FormMain.MnuSelectTop.Enabled = newState
                FormMain.MnuColorTop.Enabled = newState
                FormMain.MnuWindowTop.Enabled = newState
                
                For i = 0 To FormMain.MnuSpecificZoom.Count - 1
                    FormMain.MnuSpecificZoom(i).Enabled = newState
                Next i
                
            End If
        
        'Filter (top-level menu)
        Case tFilter
            If FormMain.MnuFilter.Enabled <> newState Then FormMain.MnuFilter.Enabled = newState
        
        'Redo (left-hand panel button AND menu item)
        Case tRedo
            If FormMain.MnuRedo.Enabled <> newState Then
                FormMain.cmdRedo.Enabled = newState
                FormMain.MnuRedo.Enabled = newState
            End If
            
            'If Redo is being enabled, change the menu text to match the relevant action that created this Undo file
            If newState Then
                FormMain.cmdRedo.ToolTip = pdImages(CurrentImage).getRedoProcessID 'GetNameOfProcess(pdImages(CurrentImage).getRedoProcessID)
                FormMain.MnuRedo.Caption = g_Language.TranslateMessage("Redo:") & " " & pdImages(CurrentImage).getRedoProcessID 'GetNameOfProcess(pdImages(CurrentImage).getRedoProcessID) '& vbTab & "Ctrl+Alt+Z"
                ResetMenuIcons
            Else
                FormMain.cmdRedo.ToolTip = ""
                FormMain.MnuRedo.Caption = g_Language.TranslateMessage("Redo")
                ResetMenuIcons
            End If
            
        'Macro (top-level menu)
        Case tMacro
            If FormMain.mnuTool(2).Enabled <> newState Then FormMain.mnuTool(2).Enabled = newState
        
        'Edit (top-level menu)
        Case tEdit
            If FormMain.MnuEdit.Enabled <> newState Then FormMain.MnuEdit.Enabled = newState
        
        'Repeat last action (menu item only)
        Case tRepeatLast
            If FormMain.MnuRepeatLast.Enabled <> newState Then FormMain.MnuRepeatLast.Enabled = newState
            
        'Selections in general
        Case tSelection
            
            'If selections are not active, clear all the selection value textboxes
            If Not newState Then
                For i = 0 To FormMain.tudSel.Count - 1
                    FormMain.tudSel(i).Value = 0
                Next i
            End If
            
            'Set selection text boxes (only the location ones!) to enable only when a selection is active.  Other selection controls can
            ' remain active even without a selection present; this allows the user to set certain parameters in advance, so when they
            ' actually draw a selection, it already has the attributes they want.
            For i = 0 To FormMain.tudSel.Count - 1
                FormMain.tudSel(i).Enabled = newState
            Next i
                                    
            'En/disable all selection menu items that rely on an existing selection to operate
            If FormMain.MnuSelect(2).Enabled <> newState Then
                
                'Select none, invert selection
                FormMain.MnuSelect(1).Enabled = newState
                FormMain.MnuSelect(2).Enabled = newState
                
                'Grow/shrink/border/feather/sharpen selection
                For i = 4 To 8
                    FormMain.MnuSelect(i).Enabled = newState
                Next i
                
                'Save selection
                FormMain.MnuSelect(11).Enabled = newState
                
            End If
                                    
            'Selection enabling/disabling also affects the Crop to Selection command
            If FormMain.MnuImage(7).Enabled <> newState Then FormMain.MnuImage(7).Enabled = newState
        
        'Transformable selection controls specifically
        Case tSelectionTransform
        
            'Under certain circumstances, it is desirable to disable only the selection location boxes
            For i = 0 To FormMain.tudSel.Count - 1
                FormMain.tudSel(i).Enabled = newState
            Next i
        
        '32bpp color mode (e.g. add/remove alpha channel).  Previously I disabled the "add alpha channel"-type options if the image was already
        ' 32bpp, but I've since changed my mind.  It may be useful to take a 32bpp image and apply a *new* alpha channel, so those options are
        ' now enabled regardless of color depth.  "Remove transparency", however, is still disabled for 24bpp images.
        Case tImgMode32bpp
            
            'FormMain.MnuTransparency(0).Enabled = Not newState
            'FormMain.MnuTransparency(1).Enabled = Not newState
            FormMain.MnuTransparency(3).Enabled = newState
            
        Case tMetadata
        
            If FormMain.MnuMetadata(0).Enabled <> newState Then FormMain.MnuMetadata(0).Enabled = newState
        
        Case tGPSMetadata
        
            If FormMain.MnuMetadata(3).Enabled <> newState Then FormMain.MnuMetadata(3).Enabled = newState
            
    End Select
    
End Sub

'Given a wordwrap label with a set size, attempt to fit the label's text inside it
Public Sub fitWordwrapLabel(ByRef srcLabel As Label, ByRef srcForm As Form)

    'We will use a pdFont object to help us measure the label in question
    Dim tmpFont As pdFont
    Set tmpFont = New pdFont
    tmpFont.setFontBold srcLabel.FontBold
    tmpFont.setFontItalic srcLabel.FontItalic
    tmpFont.setFontFace srcLabel.FontName
    tmpFont.setFontSize srcLabel.FontSize
    tmpFont.createFontObject
    tmpFont.setTextAlignment srcLabel.Alignment
    tmpFont.attachToDC srcForm.hDC
    
    'Retrieve the height from the pdFont class
    Dim lblHeight As Long
    lblHeight = tmpFont.getHeightOfWordwrapString(srcLabel.Caption, srcLabel.Width)
    
    Dim curFontSize As Long
    curFontSize = srcLabel.FontSize
    
    'If the text is too tall, shrink the font until an acceptable size is found.  Note that the reported text value tends to be
    ' smaller than the space actually required.  I do not know why this happens.  To account for it, I cut a further 10% from
    ' the requested height, just to be safe.
    If (lblHeight > srcLabel.Height * 0.9) Then
            
        'Try shrinking the font size until an acceptable width is found
        Do While (lblHeight > srcLabel.Height * 0.9) And (curFontSize >= 8)
        
            curFontSize = curFontSize - 1
            
            tmpFont.setFontSize curFontSize
            tmpFont.createFontObject
            tmpFont.attachToDC srcForm.hDC
            lblHeight = tmpFont.getHeightOfWordwrapString(srcLabel.Caption, srcLabel.Width)
            
        Loop
            
    End If
    
    'When an acceptable size is found, set it and exit.
    srcLabel.FontSize = curFontSize
    srcLabel.Refresh

End Sub

'Because VB6 apps look terrible on modern version of Windows, I do a bit of beautification to every form upon at load-time.
' This routine is nice because every form calls it at least once, so I can make centralized changes without having to rewrite
' code in every individual form.  This is also where run-time translation occurs.
Public Sub makeFormPretty(ByRef tForm As Form, Optional ByRef customTooltips As clsToolTip, Optional ByVal tooltipsAlreadyInitialized As Boolean = False)

    'Before doing anything else, make sure the form's default cursor is set to an arrow
    tForm.MouseIcon = LoadPicture("")
    tForm.MousePointer = 0

    'FORM STEP 1: Enumerate through every control on the form.  We will be making changes on-the-fly on a per-control basis.
    Dim eControl As Control
    
    For Each eControl In tForm.Controls
        
        'STEP 1: give all clickable controls a hand icon instead of the default pointer.
        ' (Note: this code will set all command buttons, scroll bars, option buttons, check boxes,
        ' list boxes, combo boxes, and file/directory/drive boxes to use the system hand cursor)
        If ((TypeOf eControl Is CommandButton) Or (TypeOf eControl Is HScrollBar) Or (TypeOf eControl Is VScrollBar) Or (TypeOf eControl Is OptionButton) Or (TypeOf eControl Is CheckBox) Or (TypeOf eControl Is ListBox) Or (TypeOf eControl Is ComboBox) Or (TypeOf eControl Is FileListBox) Or (TypeOf eControl Is DirListBox) Or (TypeOf eControl Is DriveListBox)) And (Not TypeOf eControl Is PictureBox) Then
            setHandCursor eControl
        End If
        
        'STEP 2: if the current system is Vista or later, and the user has requested modern typefaces via Edit -> Preferences,
        ' redraw all control fonts using Segoe UI.
        If ((TypeOf eControl Is TextBox) Or (TypeOf eControl Is CommandButton) Or (TypeOf eControl Is OptionButton) Or (TypeOf eControl Is CheckBox) Or (TypeOf eControl Is ListBox) Or (TypeOf eControl Is ComboBox) Or (TypeOf eControl Is FileListBox) Or (TypeOf eControl Is DirListBox) Or (TypeOf eControl Is DriveListBox) Or (TypeOf eControl Is Label)) And (Not TypeOf eControl Is PictureBox) Then
            eControl.FontName = g_InterfaceFont
        End If
        
        If ((TypeOf eControl Is jcbutton) Or (TypeOf eControl Is smartOptionButton) Or (TypeOf eControl Is smartCheckBox) Or (TypeOf eControl Is sliderTextCombo) Or (TypeOf eControl Is textUpDown) Or (TypeOf eControl Is commandBar)) Then
            eControl.Font.Name = g_InterfaceFont
        End If
                        
        'STEP 3: remove TabStop from each picture box.  They should never receive focus, but I often forget to change this
        ' at design-time.
        If (TypeOf eControl Is PictureBox) Then eControl.TabStop = False
                        
        'STEP 4: correct tab stops so that the OK button is always 0, and Cancel is always 1
        If (TypeOf eControl Is CommandButton) Then
            If (eControl.Caption = "&OK") Then
                If eControl.TabIndex <> 0 Then eControl.TabIndex = 0
            End If
        End If
        If (TypeOf eControl Is CommandButton) Then
            If (eControl.Caption = "&Cancel") Then eControl.TabIndex = 1
        End If
                
    Next
    
    'FORM STEP 2: subclass this form and force controls to render transparent borders properly.
    If g_IsProgramCompiled Then SubclassFrame tForm.hWnd, False
    
    'FORM STEP 3: translate the form (and all controls on it)
    If g_Language.translationActive And tForm.Enabled Then
        g_Language.activateShortcut tForm.Name
        g_Language.applyTranslations tForm
        g_Language.deactivateShortcut
    End If
    
    'FORM STEP 4: if a custom tooltip handler was passed in, activate and populate it now.
    If Not (customTooltips Is Nothing) Then
        
        'In rare cases, the custom tooltip handler passed to this function may already be initialized.  Some forms
        ' do this if they need to handle multiline tooltips (as VB will not handle them properly).  If the class has
        ' NOT been initialized, we can do so now - otherwise, trust that it was already created correctly.
        If Not tooltipsAlreadyInitialized Then
            customTooltips.Create tForm
            customTooltips.MaxTipWidth = PD_MAX_TOOLTIP_WIDTH
            customTooltips.DelayTime(ttDelayShow) = 10000
        End If
        
        'Once again, enumerate every control on the form and copy their tooltips into this object.  (This allows
        ' for things like automatic multiline support, unsupported characters, theming, and displaying tooltips
        ' on the correct monitor of a multimonitor setup.)
        Dim tmpTooltip As String
        For Each eControl In tForm.Controls
            
            If (TypeOf eControl Is CommandButton) Or (TypeOf eControl Is CheckBox) Or (TypeOf eControl Is OptionButton) Or (TypeOf eControl Is PictureBox) Or (TypeOf eControl Is TextBox) Or (TypeOf eControl Is ListBox) Or (TypeOf eControl Is ComboBox) Then
                If (Trim(eControl.ToolTipText) <> "") Then
                    tmpTooltip = eControl.ToolTipText
                    eControl.ToolTipText = ""
                    customTooltips.AddTool eControl, tmpTooltip
                End If
            End If
        Next
        
    End If
    
    
    'Refresh all non-MDI forms after making the changes above
    If tForm.Name <> "FormMain" Then
        tForm.Refresh
    Else
        'The main from is a bit different - if it has been translated or changed, it needs menu icons reassigned.
        If FormMain.Visible Then ApplyAllMenuIcons
    End If
        
End Sub


'Used to enable font smoothing if currently disabled.
Public Sub handleClearType(ByVal startingProgram As Boolean)
    
    'At start-up, activate ClearType.  At shutdown, restore the original setting (as necessary).
    If startingProgram Then
    
        hadToChangeSmoothing = 0
    
        'Get current font smoothing setting
        Dim pv As Long
        SystemParametersInfo SPI_GETFONTSMOOTHING, 0, pv, 0
        
        'If font smoothing is disabled, mark it
        If pv = 0 Then hadToChangeSmoothing = 2
        
        'If font smoothing is enabled but set to Standard instead of ClearType, mark it
        If pv <> 0 Then
            SystemParametersInfo SPI_GETFONTSMOOTHINGTYPE, 0, pv, 0
            If pv = SmoothingStandardType Then hadToChangeSmoothing = 1
        End If
        
        Select Case hadToChangeSmoothing
        
            'ClearType is enabled, no changes necessary
            Case 0
            
            'Standard smoothing is enabled; switch it to ClearType for the duration of the program
            Case 1
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingClearType, 0
                
            'No smoothing is enabled; turn it on and activate ClearType for the duration of the program
            Case 2
                SystemParametersInfo SPI_SETFONTSMOOTHING, 1, pv, 0
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingClearType, 0
            
        End Select
    
    Else
        
        Select Case hadToChangeSmoothing
        
            'ClearType was enabled, no action necessary
            Case 0
            
            'Standard smoothing was enabled; restore it now
            Case 1
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingStandardType, 0
                
            'No smoothing was enabled; restore that setting now
            Case 2
                SystemParametersInfo SPI_SETFONTSMOOTHING, 0, pv, 0
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingNone, 0
        
        End Select
    
    End If
    
End Sub

'This sub is used to render control backgrounds as transparent
Public Sub SubclassFrame(FramehWnd As Long, ReleaseSubclass As Boolean)
    Dim prevProc As Long
    
    prevProc = GetProp(FramehWnd, "scPproc")
    If ReleaseSubclass Then
        If prevProc Then
            SetWindowLong FramehWnd, GWL_WNDPROC, prevProc
            SetProp FramehWnd, "scPproc", 0&
        End If
    ElseIf prevProc = 0& Then
        SetProp FramehWnd, "scPproc", GetWindowLong(FramehWnd, GWL_WNDPROC)
        SetWindowLong FramehWnd, GWL_WNDPROC, AddressOf WndProc_Frame
    End If
End Sub

Private Function WndProc_Frame(ByVal hWnd As Long, ByVal uMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    
    Dim prevProc As Long
    
    prevProc = GetProp(hWnd, "scPproc")
    If prevProc = 0& Then
        WndProc_Frame = DefWindowProc(hWnd, uMsg, wParam, lParam)
    ElseIf uMsg = WM_PRINTCLIENT Then
        SendMessage hWnd, WM_PAINT, wParam, ByVal 0&
    Else
        If uMsg = WM_DESTROY Then SubclassFrame hWnd, True
        WndProc_Frame = CallWindowProc(prevProc, hWnd, uMsg, wParam, lParam)
    End If
End Function

'The next two subs can be used to show or hide the left and right toolbar panes.  An input parameter can be specified to force behavior.
' INPUT VALUES:
' 0 (or none) - toggle the visibility to the opposite state (const VISIBILITY_TOGGLE)
' 1 - make the pane visible                                 (const VISIBILITY_FORCEDISPLAY)
' 2 - hide the pane                                         (const VISIBILITY_FORCEHIDE)
Public Sub ChangeLeftPane(Optional ByVal howToToggle As Long = 0)

    Select Case howToToggle
    
        Case VISIBILITY_TOGGLE
        
            'Write the new value to the preferences files
            g_UserPreferences.SetPref_Boolean "General Preferences", "HideLeftPanel", Not g_UserPreferences.GetPref_Boolean("General Preferences", "HideLeftPanel", False)

            'Toggle the text and picture box accordingly
            If g_UserPreferences.GetPref_Boolean("General Preferences", "HideLeftPanel", False) Then
                FormMain.MnuLeftPanel.Caption = g_Language.TranslateMessage("Show left panel (file tools)")
                FormMain.picLeftPane.Visible = False
            Else
                FormMain.MnuLeftPanel.Caption = g_Language.TranslateMessage("Hide left panel (file tools)")
                FormMain.picLeftPane.Visible = True
            End If
    
            'Ask the menu icon handler to redraw the menu image with the new icon
            ResetMenuIcons
        
        Case VISIBILITY_FORCEDISPLAY
            FormMain.MnuLeftPanel.Caption = g_Language.TranslateMessage("Hide left panel (file tools)")
            FormMain.picLeftPane.Visible = True
            
        Case VISIBILITY_FORCEHIDE
            FormMain.MnuLeftPanel.Caption = g_Language.TranslateMessage("Show left panel (file tools)")
            FormMain.picLeftPane.Visible = False
            
    End Select

End Sub

Public Sub ChangeRightPane(Optional ByVal howToToggle As Long)

    Select Case howToToggle
    
        Case VISIBILITY_TOGGLE
        
            'Write the new value to the preferences file
            g_UserPreferences.SetPref_Boolean "General Preferences", "HideRightPanel", Not g_UserPreferences.GetPref_Boolean("General Preferences", "HideRightPanel", False)

            'Toggle the text and picture box accordingly
            If g_UserPreferences.GetPref_Boolean("General Preferences", "HideRightPanel", False) Then
                FormMain.MnuRightPanel.Caption = g_Language.TranslateMessage("Show right panel (image tools)")
                FormMain.picRightPane.Visible = False
            Else
                FormMain.MnuRightPanel.Caption = g_Language.TranslateMessage("Hide right panel (image tools)")
                FormMain.picRightPane.Visible = True
            End If
    
            'Ask the menu icon handler to redraw the menu image with the new icon
            ResetMenuIcons
        
        Case VISIBILITY_FORCEDISPLAY
            FormMain.MnuRightPanel.Caption = g_Language.TranslateMessage("Hide right panel (image tools)")
            FormMain.picRightPane.Visible = True
            
        Case VISIBILITY_FORCEHIDE
            FormMain.MnuRightPanel.Caption = g_Language.TranslateMessage("Show right panel (image tools)")
            FormMain.picRightPane.Visible = False
            
    End Select

End Sub

'When a themed form is unloaded, it may be desirable to release certain changes made to it - or in our case, unsubclass it.
' This function should be called when any themed form is unloaded.
Public Sub ReleaseFormTheming(ByRef tForm As Form)
    If g_IsProgramCompiled Then SubclassFrame tForm.hWnd, True
    Set tForm = Nothing
End Sub

'Perform any drawing routines related to the main form
Public Sub RedrawMainForm()

    'Draw a subtle gradient on either pane if visible.
    ' NOTE: this is momentarily disabled as part of tool implementation.  I may revisit it in the future.
    If FormMain.picLeftPane.Visible Then
        FormMain.picLeftPane.Refresh
        'DrawGradient FormMain.picLeftPane, RGB(240, 240, 240), RGB(201, 211, 226), True
    End If
    
    If FormMain.picRightPane.Visible Then
        FormMain.picRightPane.Refresh
        'DrawGradient FormMain.picRightPane, RGB(201, 211, 226), RGB(240, 240, 240), True
    End If
    
    'Redraw the progress bar
    FormMain.picProgBar.Refresh
    g_ProgBar.Draw
    
End Sub

'Display the specified size in the main form's status bar
Public Sub DisplaySize(ByVal iWidth As Long, ByVal iHeight As Long)
    
    FormMain.lblImgSize.Caption = g_Language.TranslateMessage("size") & ":" & vbCrLf & iWidth & "x" & iHeight
    FormMain.lblImgSize.Refresh
    
    'Size is only displayed when it is changed, so if any controls have a maxmimum value linked to the size of the image,
    ' now is an excellent time to update them.
    If iWidth < iHeight Then
        FormMain.sltSelectionBorder.Max = iWidth
        FormMain.sltCornerRounding.Max = iWidth
        FormMain.sltSelectionLineWidth.Max = iHeight
    Else
        FormMain.sltSelectionBorder.Max = iHeight
        FormMain.sltCornerRounding.Max = iHeight
        FormMain.sltSelectionLineWidth.Max = iWidth
    End If
    
End Sub

'PhotoDemon's software processor requires that all parameters be passed as a string, with individual parameters separated by
' the "|" character.  This function can be used to automatically assemble any number of parameters into such a string.
Public Function buildParams(ParamArray allParams() As Variant) As String

    buildParams = ""

    If Not IsMissing(allParams) Then
    
        Dim i As Long
        For i = LBound(allParams) To UBound(allParams)
            buildParams = buildParams & CStr(allParams(i))
            If i < UBound(allParams) Then buildParams = buildParams & "|"
        Next i
    
    End If

End Function

'This wrapper is used in place of the standard MsgBox function.  At present it's just a wrapper around MsgBox, but
' in the future I may replace the dialog function with something custom.
Public Function pdMsgBox(ByVal pMessage As String, ByVal pButtons As VbMsgBoxStyle, ByVal pTitle As String, ParamArray ExtraText() As Variant) As VbMsgBoxResult

    Dim newMessage As String, newTitle As String
    newMessage = pMessage
    newTitle = pTitle

    'All messages are translatable, but we don't want to translate them if the translation object isn't ready yet
    If (Not (g_Language Is Nothing)) Then
        If g_Language.readyToTranslate Then
            If g_Language.translationActive Then
                newMessage = g_Language.TranslateMessage(pMessage)
                newTitle = g_Language.TranslateMessage(pTitle)
            End If
        End If
    End If
    
    'Once the message is translated, we can add back in any optional parameters
    If Not IsMissing(ExtraText) Then
    
        Dim i As Long
        For i = LBound(ExtraText) To UBound(ExtraText)
            newMessage = Replace$(newMessage, "%" & i + 1, CStr(ExtraText(i)))
        Next i
    
    End If

    pdMsgBox = MsgBox(newMessage, pButtons, newTitle)

End Function

'This popular function is used to display a message in the main form's status bar.
' INPUTS:
' 1) the message to be displayed (mString)
' *2) any values that must be calculated at run-time, which are labeled in the message string by "%n"
Public Sub Message(ByVal mString As String, ParamArray ExtraText() As Variant)

    Dim newString As String
    newString = mString

    'All messages are translatable, but we don't want to translate them if the translation object isn't ready yet
    If (Not (g_Language Is Nothing)) Then
        If g_Language.readyToTranslate Then
            If g_Language.translationActive Then newString = g_Language.TranslateMessage(mString)
        End If
    End If
    
    'Once the message is translated, we can add back in any optional parameters
    If Not IsMissing(ExtraText) Then
    
        Dim i As Long
        For i = LBound(ExtraText) To UBound(ExtraText)
            newString = Replace$(newString, "%" & i + 1, CStr(ExtraText(i)))
        Next i
    
    End If

    If MacroStatus = MacroSTART Then newString = newString & " {-" & g_Language.TranslateMessage("Recording") & "-}"
    
    If MacroStatus <> MacroBATCH Then
        If FormMain.Visible Then
            g_ProgBar.Text = newString
            g_ProgBar.Draw
        End If
    End If
    
    If Not g_IsProgramCompiled Then Debug.Print newString
    
    'If we're logging program messages, open up a log file and dump the message there
    If g_LogProgramMessages = True Then
        Dim fileNum As Integer
        fileNum = FreeFile
        Open g_UserPreferences.getDataPath & PROGRAMNAME & "_DebugMessages.log" For Append As #fileNum
            Print #fileNum, mString
            If mString = "Finished." Then Print #fileNum, vbCrLf
        Close #fileNum
    End If
    
End Sub

'Pass AutoSelectText a text box and it will select all text currently in the text box
Public Function AutoSelectText(ByRef tBox As TextBox)
    If Not tBox.Visible Then Exit Function
    If Not tBox.Enabled Then Exit Function
    tBox.SetFocus
    tBox.SelStart = 0
    tBox.SelLength = Len(tBox.Text)
End Function

'When the mouse is moved outside the primary image, clear the image coordinates display
Public Sub ClearImageCoordinatesDisplay()
    FormMain.lblCoordinates.Caption = ""
    FormMain.lblCoordinates.Refresh
End Sub

'Populate the passed combo box with options related to distort filter edge-handle options.  Also, select the specified method by default.
Public Sub popDistortEdgeBox(ByRef cmbEdges As ComboBox, Optional ByVal defaultEdgeMethod As EDGE_OPERATOR)

    cmbEdges.Clear
    cmbEdges.AddItem " clamp them to the nearest available pixel"
    cmbEdges.AddItem " reflect them across the nearest edge"
    cmbEdges.AddItem " wrap them around the image"
    cmbEdges.AddItem " erase them"
    cmbEdges.AddItem " ignore them"
    cmbEdges.ListIndex = defaultEdgeMethod
    
End Sub

'Return the width (and below, height) of a string, in pixels, according to the font assigned to fontContainerDC
Public Function getPixelWidthOfString(ByVal srcString As String, ByVal fontContainerDC As Long) As Long
    Dim txtSize As POINTAPI
    GetTextExtentPoint32 fontContainerDC, srcString, Len(srcString), txtSize
    getPixelWidthOfString = txtSize.x
End Function

Public Function getPixelHeightOfString(ByVal srcString As String, ByVal fontContainerDC As Long) As Long
    Dim txtSize As POINTAPI
    GetTextExtentPoint32 fontContainerDC, srcString, Len(srcString), txtSize
    getPixelHeightOfString = txtSize.y
End Function
