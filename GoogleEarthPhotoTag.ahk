; GoogleEarthPhotoTag.ahk  version 1.00
; by David Tryse   davidtryse@gmail.com
; http://david.tryse.net/googleearth/
; License:  GPL 2+
; 
; Script for AutoHotkey   ( http://www.autohotkey.com/ )
; Creates a GUI for viewing Exif GPS data in JPEG files
; * can read coordinates from the Google Earth client and write to JPEG files
; * can be used from command line / when right-clicking on JPEG files (view About: window to register)
; * can show/delete Exif GPS tag from files
; * "Auto-Mode" : jpeg files drag-and-dropped to the window will automatically be tagged with the current Google Earth coordinates
; 
; Needs _libGoogleEarth.ahk library:  http://david.tryse.net/googleearth/
; Needs ws4ahk.ahk library:  http://www.autohotkey.net/~easycom/
; Needs exiv2.exe to read/write Exif GPS data:  http://www.exiv2.org/
; Will optionally use cmdret.dll if present (to avoid temp files for command output):  http://www.autohotkey.com/forum/topic3687.html

; TODO
; multi-select (del and save)
; open all - KML
; read altitude?
#NoEnv
#SingleInstance off
#NoTrayIcon 
#Include _libGoogleEarth.ahk
version = 1.00

; ------------ find exiv2.exe -----------
EnvGet, EnvPath, Path
EnvPath := A_ScriptDir ";" A_ScriptDir "\exiv2;" EnvPath
Loop, Parse, EnvPath, `;
{
	IfExist, %A_LoopField%\exiv2.exe
		exiv2path = %A_LoopField%\exiv2.exe
}
IfEqual exiv2path
{
	RegRead exiv2path, HKEY_CURRENT_USER, SOFTWARE\GoogleEarthPhotoTag, exiv2path
	IfEqual exiv2path
		FileSelectFile, exiv2path, 3,, Provide path to exiv2.exe, Exiv2.exe (exiv2.exe)
	IfEqual exiv2path
	{
		Msgbox,48, Cannot find exiv2.exe, Error: This tool needs exiv2.exe`nIt can be downloaded for free from www.exiv2.org
		ExitApp
	} else {
		RegWrite REG_SZ, HKEY_CURRENT_USER, SOFTWARE\GoogleEarthPhotoTag, exiv2path, %exiv2path%
	}
}

; ---------------- handle command line parameters ("single-photo" = fly to, /SavePos "single-photo"= write coordinates) -------------------
If 0 > 0
{
	If 1 = /SavePos		; use GoogleEarthPhotoTag.exe /SavePos "c:\photos\DSC02083.JPG" to save the current Google Earth coordinates to this photo
	{
		If IsGErunning() {
			filename = %2%
			If FileExist(filename) {
				SplitPath filename, File, Folder, Ext
				GetGEpos(FocusPointLatitude, FocusPointLongitude, FocusPointAltitude, FocusPointAltitudeMode, Range, Tilt, Azimuth)
				FocusPointLatitude := Round(FocusPointLatitude,6)
				FocusPointLongitude := Round(FocusPointLongitude,6)
				If (FocusPointLongitude = "") or (FocusPointLatitude = "") {
					Msgbox,48, Write Coordinates, Error: Failed to get coordinates from Google Earth.
				} else {
					SetPhotoLatLong(Folder "\" File, FocusPointLatitude, FocusPointLongitude, exiv2path)
					GetPhotoLatLong(Folder "\" File, FileLatitude, FileLongitude, exiv2path)
					If (Dec2Deg(FileLatitude) = Dec2Deg(FocusPointLatitude)) and (Dec2Deg(FileLongitude) = Dec2Deg(FocusPointLongitude)) {    ; cannot compare directly without Dec2Deg() as 41.357892/41.357893 both equal 41� 21' 28.41'' N etc..
						Msgbox,, Write Coordinates, Coordinates %FocusPointLatitude%`,%FocusPointLongitude% successfully written to %File%
					} else {
						Msgbox,48, Write Coordinates, Error: Failed to write coordinates %FocusPointLatitude%`,%FocusPointLongitude% to %File%
					}
				}
			} else {
				Msgbox,48, Write Coordinates, Error: File does not exist: %filename%
			}
		} else {
			Msgbox,48, Write Coordinates, Error: Google Earth is not running - cannot read coordinates.
		}
	} else {		; use GoogleEarthPhotoTag.exe "c:\photos\DSC02083.JPG" to fly in Google Earth to the coordinates stored in this photo
		filename = %1%
		If FileExist(filename) {
			SplitPath filename, File, Folder, Ext
			GetPhotoLatLong(Folder "\" File, FileLatitude, FileLongitude, exiv2path)
			If (FileLatitude = "") or (FileLongitude = "") {
				Msgbox,48, Read Coordinates, Error: No Exif GPS data in file: %filename% %FileLatitude%, %FileLongitude%
			} else {
				If IsGErunning() {
					SetGEpos(FileLatitude, FileLongitude, 0, 2, 10000, 0, 0)
					Msgbox,, Read Coordinates, Locating coordinates %FileLatitude%`,%FileLongitude% in Google Earth..., 2
				} else {
					Msgbox,48, Read Coordinates, Error: Google Earth is not running - cannot fly to coordinates %FileLatitude%`,%FileLongitude%.
				}
			}
		}else{
			Msgbox,48, Read Coordinates, Error: File does not exist: %filename%
		}
	}
	ExitApp
}

FileInstall cmdret.dll, %A_Temp%\cmdret.dll, 1

; -------- create right-click menu -------------
Menu, contex, add, Window On Top, OnTop
Menu, contex, add, About, About

; ----------- create GUI ----------------
Gui Add, Button, ym xm vAddFiles gAddFiles w74, &Add Files...
Gui Add, Text, yp+3 xp+77 , (also drag-and-drop)
Gui Add, Button, yp-3 xp+112 vClear gClear, &Clear List
Gui Add, Button, yp xp+59 vReread gReread, &Reread Exif
Gui Add, Text, ym+2 xm+330 , Google Earth coordinates:
Gui Add, Edit, yp-3 xp+129 w73 +ReadOnly vFocusPointLatitude,
Gui Add, Edit, yp-0 xp+74  w73 +ReadOnly vFocusPointLongitude,

Gui Add, ListView, r11 -Multi xm+0 yp+30 w606 vListView gListView, File|Latitude|Longitude|Log|Folder
LV_ModifyCol(2, "Integer")  ; For sorting purposes, indicate that column is an integer.
LV_ModifyCol(3, "Integer")

Gui Add, Button, ym+210 xm+0 vOpenPhoto gOpenPhoto default, &Open photo
Gui Add, Button, yp xp+76 vShowExif gShowExif, Show &Exif
Gui Add, Button, yp xp+62 vDeleteExif gDeleteExif, Delete Exif
Gui Add, Button, yp xp+75 vFlyTo gFlyTo, &Fly to this photo in Google Earth
Gui Add, Button, yp xp+169 vSavePos gSavePos, &Save Google Earth coordinates to this photo
;Gui Add, Button, yp x0 hidden vreload greload, reloa&d

Gui Font, bold
Gui Add, Checkbox, yp+30 xm+6 vAutoMode, %A_Space%Auto-Mode 
Gui font, norm
Gui Add, text, yp xp+89, (any new files added will automatically be tagged with the current Google Earth coordinates)
Gui Add, Button, yp-2 xp+471 h18 w40 vAbout gAbout, &?

Gui Add, StatusBar
SB_SetText(" This tool requires exiv2.exe from http://www.exiv2.org/")  ; update statusbar
Gui Show, X100 Y700, Google Earth PhotoTag %version%
Gui +Minsize

; ------------- continous loop to track Google Earth coordinates -------------
Loop {
	If IsGErunning() {
		GetGEpos(FocusPointLatitude, FocusPointLongitude, FocusPointAltitude, FocusPointAltitudeMode, Range, Tilt, Azimuth)
		FocusPointLatitude := Round(FocusPointLatitude,6)
		FocusPointLongitude := Round(FocusPointLongitude,6)
		GuiControl,,FocusPointLatitude, %FocusPointLatitude%
		GuiControl,,FocusPointLongitude, %FocusPointLongitude%
	} else {
		GuiControl,,FocusPointLatitude, not running
		GuiControl,,FocusPointLongitude,
		SB_SetText(" Google Earth is not running.")  ; update statusbar
	}
	Sleep 300
}


; ----------- find currently selected jpeg file in the list view ------------
FindFocused:
  File =
  ListLatitude =
  ListLongitude =
  Folder =
  FocusedRowNumber := LV_GetNext(0, "F")  ; Find the focused row.
  if not FocusedRowNumber   ; No row is focused.
	return
  LV_GetText(File, FocusedRowNumber, 1)
  LV_GetText(ListLatitude, FocusedRowNumber, 2)
  LV_GetText(ListLongitude, FocusedRowNumber, 3)
  LV_GetText(Folder, FocusedRowNumber, 5)
return

; --------------- add new file to listview (+write GE coordinates if auto-mode checked) ----------
AddFileToList:
  Gui, Submit, NoHide
  If (AutoMode) and IsGErunning() {
	Gosub WriteExif
  } else {
	Gosub ReadExif
  }
  LV_Add("", File, FileLatitude, FileLongitude, logmsg, Folder)
return

; ------------ read Exif GPS data from file ----------------
ReadExif:
  GetPhotoLatLong(Folder "\" File, FileLatitude, FileLongitude, exiv2path)
  logmsg := "read Exif failed"
  If (FileLatitude != "") and (FileLongitude != "") 
	logmsg := "read Exif ok"
return

; ----------- write Exif GPS data to file ---------------
WriteExif:
  If IsGErunning() {
	SB_SetText("Writing coordinates " FocusPointLatitude ", " FocusPointLongitude " to file " File )  ; update statusbar
	logmsg := "write Exif failed"
	SetPhotoLatLong(Folder "\" File, FocusPointLatitude, FocusPointLongitude, exiv2path)
	GetPhotoLatLong(Folder "\" File, FileLatitude, FileLongitude, exiv2path)
	If (Dec2Deg(FileLatitude) = Dec2Deg(FocusPointLatitude)) and (Dec2Deg(FileLongitude) = Dec2Deg(FocusPointLongitude))    ; cannot compare directly without Dec2Deg() as 41.357892/41.357893 both equal 41� 21' 28.41'' N etc..
		logmsg := "write Exif ok"
  }
return

; =================================================== functions for GUI buttons ============================================================

AddFiles:
  Gui +OwnDialogs
  FileSelectFile, SelectedFiles, M3,, Open JPEG files..., JPEG files (*.jpg; *.jpeg)
  If SelectedFiles =
	return
  Loop, parse, SelectedFiles, `n
  {
	If (A_Index = 1) {
		Folder := A_LoopField
		Continue
	}
	File := A_LoopField
	Gosub AddFileToList
	LV_ModifyCol()  ; Auto-size each column to fit its contents.
  }
return

Clear:
  LV_Delete() ; delete all rows in listview
  SB_SetText("Clear...")  ; update statusbar
return

Reread:
  Loop % LV_GetCount()
  {
	LV_GetText(File, A_Index, 1)
	LV_GetText(ListLatitude, A_Index, 2)
	LV_GetText(ListLongitude, A_Index, 3)
	LV_GetText(Folder, A_Index, 5)
	Gosub ReadExif
	LV_Modify(A_Index, Col1, File, FileLatitude, FileLongitude, logmsg, Folder)
	SB_SetText("Exif data re-read for " A_Index " files.")  ; update statusbar
  }
  LV_ModifyCol()  ; Auto-size each column to fit its contents.
return

OpenPhoto:
  Gosub FindFocused
  IfNotEqual File
	Run %Folder%\%File%    ; open jpeg in default application
return

ShowExif:
  Gosub FindFocused
  IfEqual File
	return
  GetExif(Folder "\" File, ExifData, exiv2path)
  msgbox, 8192, Exif data for %File%, %ExifData%       ; show all Exif data in standard message-box...ugly
return

DeleteExif:
  Gosub FindFocused
  IfEqual File
	return
  SB_SetText("Deleting Exif GPS data from " File )  ; update statusbar
  ErasePhotoLatLong(Folder "\" File, exiv2path)
  Gosub ReadExif
  logmsg = delete failed
  If not FileLatitude and not FileLongitude
	logmsg = delete ok
  LV_Modify(FocusedRowNumber, Col1, File, FileLatitude, FileLongitude, logmsg, Folder)
return

FlyTo:
  If IsGErunning() {
	Gosub FindFocused
	IfNotEqual File
		SetGEpos(ListLatitude, ListLongitude, 0, 2, 10000, 0, 0)
  } else {
	SB_SetText(" Google Earth is not running.")  ; update statusbar
  }
return

SavePos:
  If IsGErunning() {
	  Gosub FindFocused
	  IfEqual File
		return
	  Gosub WriteExif
	  LV_Modify(FocusedRowNumber, Col1, File, FileLatitude, FileLongitude, logmsg, Folder)
  } else {
	SB_SetText(" Google Earth is not running.")  ; update statusbar
  }
return

; ==========================================================================================================================

GuiDropFiles:
  Loop, parse, A_GuiEvent, `n
  {
	If InStr(FileExist(A_LoopField), "D") {   ; if dragged item is a directory loop to add all jpg files
		Loop %A_LoopField%\*.jpg,,1
		{
			SplitPath A_LoopFileFullPath, File, Folder, Ext
			Gosub AddFileToList
			LV_ModifyCol()  ; Auto-size each column to fit its contents.
			SB_SetText(A_Index " files added.")  ; update statusbar
		}
		Loop %A_LoopField%\*.jpeg,,1
		{
			SplitPath A_LoopFileFullPath, File, Folder, Ext
			Gosub AddFileToList
			LV_ModifyCol()  ; Auto-size each column to fit its contents.
			SB_SetText(A_Index " files added.")  ; update statusbar
		}
		Continue
	}
	SplitPath A_LoopField, File, Folder, Ext
	If (Ext = "jpg" or Ext = "jpeg") {
		Gosub AddFileToList
		LV_ModifyCol()  ; Auto-size each column to fit its contents.
	}
	SB_SetText(A_Index " files added.")  ; update statusbar
  }
return

reload:
  Reload
return

OnTop:
  Menu, contex, ToggleCheck, %A_ThisMenuItem%
  Winset, AlwaysOnTop, Toggle, A
return

ListView:
  If A_GuiEvent = DoubleClick
	Gosub OpenPhoto
return

GuiContextMenu:
  if A_GuiControl != ListView 
	Menu, contex, Show
return

GuiClose:
  ;FileDelete %A_Temp%\cmdret.dll
ExitApp

About:
  Gui 2:Destroy
  Gui 2:+Owner
  Gui 1:+Disabled
  Gui 2:Font,Bold
  Gui 2:Add,Text,x+0 yp+10, Google Earth PhotoTag %version%
  Gui 2:Font
  Gui 2:Add,Text,xm yp+22, A small program for adding Exif GPS data to JPEG files
  Gui 2:Add,Text,xm yp+15, and reading coordinates from the Google Earth client.
  Gui 2:Add,Text,xm yp+18, License: GPL
  Gui 2:Add,Button,gAssoc x40 yp+26 w200, &Add right-click options to JPEG files
  Gui 2:Add,Text,xm yp+36, Check for updates here:
  Gui 2:Font,CBlue Underline
  Gui 2:Add,Text,xm gWeblink yp+15, http://david.tryse.net/googleearth/
  Gui 2:Font
  Gui 2:Add,Text,xm yp+20, For bug reports or ideas email:
  Gui 2:Font,CBlue Underline
  Gui 2:Add,Text,xm gEmaillink yp+15, davidtryse@gmail.com
  Gui 2:Font
  Gui 2:Add,Text,xm yp+28, This program requires exiv2.exe:
  Gui 2:Font,CBlue Underline
  Gui 2:Add,Text,xm gExiv2link yp+15, http://www.exiv2.org/
  Gui 2:Font
  Gui 2:Add,Button,gAboutOk Default w80 h80 yp-50 x180,&OK
  Gui 2:Show,,About: Google Earth PhotoTag
Return

AboutOk:
  Gui 1:-Disabled
  Gui 2:Destroy
return

Weblink:
Run, http://david.tryse.net/googleearth/,,UseErrorLevel
Return

Emaillink:
Run, mailto:davidtryse@gmail.com,,UseErrorLevel
Return

Exiv2link:
Run, http://www.exiv2.org/,,UseErrorLevel
Return

2GuiClose:
Gui 1:-Disabled
Gui 2:Destroy
return

Assoc:
  Gui +OwnDialogs
  RegRead JpegReg, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\.jpg
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSRead\command , , "%A_ScriptFullPath%" "`%1"
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSRead , , Read Google Earth coordinates from file
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSWrite\command , , "%A_ScriptFullPath%" /SavePos "`%1"
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSWrite , , Write Google Earth coordinates to file
  RegRead JpegReg, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\.jpeg
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSRead\command , , "%A_ScriptFullPath%" "`%1"
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSRead , , Read Google Earth coordinates from file
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSWrite\command , , "%A_ScriptFullPath%" /SavePos "`%1"
  RegWrite REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Classes\%JpegReg%\shell\GPSWrite , , Write Google Earth coordinates to file
  MsgBox,, Registry Options, You can now right-click JPEG files to read/save GPS coordinates
return
