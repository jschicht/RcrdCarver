#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\..\..\Program Files (x86)\autoit-v3.3.14.2\Icons\au3.ico
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=Extracts raw RCRD records
#AutoIt3Wrapper_Res_Description=Extracts raw RCRD records
#AutoIt3Wrapper_Res_Fileversion=1.0.0.4
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Include <WinAPIEx.au3>

Global Const $FILEsig = "46494c45"
Global Const $INDXsig = "494E4458"
Global Const $RCRDsig = "52435244"
Global Const $RCRD_Size = 4096
Global $File,$OutputPath,$PageSize=4096

ConsoleWrite("RcrdCarver v1.0.0.4" & @CRLF)

_GetInputParams()

$TimestampStart = @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & "-" & @MIN & "-" & @SEC
$logfilename = $OutputPath & "\Carver_Rcrd_" & $TimestampStart & ".log"
$logfile = FileOpen($logfilename,2+32)
If @error Then
	ConsoleWrite("Error creating: " & $logfilename & @CRLF)
	Exit
EndIf

$OutFileWithFixups = $OutputPath & "\Carver_Rcrd_" & $TimestampStart & ".wfixups.RCRD"
If FileExists($OutFileWithFixups) Then
	_DebugOut("Error outfile exist: " & $OutFileWithFixups)
	Exit
EndIf
$OutFileWithoutFixups = $OutputPath & "\Carver_Rcrd_" & $TimestampStart & ".wofixups.RCRD"
If FileExists($OutFileWithoutFixups) Then
	_DebugOut("Error outfile exist: " & $OutFileWithoutFixups)
	Exit
EndIf
$OutFileFalsePositives = $OutputPath & "\Carver_Rcrd_" & $TimestampStart & ".false.positive.RCRD"
If FileExists($OutFileFalsePositives) Then
	_DebugOut("Error outfile exist: " & $OutFileFalsePositives)
	Exit
EndIf

$FileSize = FileGetSize($File)
If $FileSize = 0 Then
	ConsoleWrite("Error retrieving file size" & @CRLF)
	Exit
EndIf

_DebugOut("Input: " & $File)
_DebugOut("Input filesize: " & $FileSize & " bytes")
_DebugOut("OutFileWithFixups: " & $OutFileWithFixups)
_DebugOut("OutFileWithoutFixups: " & $OutFileWithoutFixups)
_DebugOut("OutFileFalsePositives: " & $OutFileFalsePositives)
_DebugOut("RCRD size configuration: " & $RCRD_Size)

$hFile = _WinAPI_CreateFile("\\.\" & $File,2,2,7)
If $hFile = 0 Then
	_DebugOut("CreateFile error on " & $File & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf
$hFileOutWithFixups = _WinAPI_CreateFile("\\.\" & $OutFileWithFixups,3,6,7)
If $hFileOutWithFixups = 0 Then
	_DebugOut("CreateFile error on " & $OutFileWithFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf
$hFileOutWithoutFixups = _WinAPI_CreateFile("\\.\" & $OutFileWithoutFixups,3,6,7)
If $hFileOutWithoutFixups = 0 Then
	_DebugOut("CreateFile error on " & $OutFileWithoutFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf
$hFileOutFalsePositives = _WinAPI_CreateFile("\\.\" & $OutFileFalsePositives,3,6,7)
If $hFileOutFalsePositives = 0 Then
	_DebugOut("CreateFile error on " & $OutFileFalsePositives & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf

$rBuffer = DllStructCreate("byte ["&$RCRD_Size&"]")
$BigBuffSize = 512 * 1000
$rBufferBig = DllStructCreate("byte ["&$BigBuffSize&"]")

$NextOffset = 0
$FalsePositivesCounter = 0
$RecordsWithFixupsCounter = 0
$RecordsWithoutFixupsCounter = 0
$nBytes = ""
$Timerstart = TimerInit()
Do
	If IsInt(Mod(($NextOffset),$FileSize)/1000000) Then ConsoleWrite(Round((($NextOffset)/$FileSize)*100,2) & " %" & @CRLF)
	If Not _WinAPI_SetFilePointerEx($hFile, $NextOffset, $FILE_BEGIN) Then
		_DebugOut("SetFilePointerEx error on offset " & $NextOffset & @CRLF)
		Exit
	EndIf
	If Not _WinAPI_ReadFile($hFile, DllStructGetPtr($rBufferBig), $BigBuffSize, $nBytes) Then
		_DebugOut("ReadFile error on offset " & $NextOffset & @CRLF)
		Exit
	EndIf
	$DataChunkBig = DllStructGetData($rBufferBig, 1)

	$OffsetTest = StringInStr($DataChunkBig,$RCRDsig)

	If Not $OffsetTest Then
		$NextOffset += $BigBuffSize
		ContinueLoop
	EndIf
	If $NextOffset > 0 Then
		If Mod($OffsetTest,2)=0 Then
			;We can only consider bytes, not nibbles
			$NextOffset += $NextOffset/2
			ContinueLoop
		EndIf
		If $OffsetTest >= ($NextOffset*2) - ($PageSize*2) Then
			$NextOffset += (($OffsetTest-3)/2)
			ContinueLoop
		EndIf
	EndIf

	$RCRDOffset = (($OffsetTest-3)/2)
	If Not _WinAPI_SetFilePointerEx($hFile, $RCRDOffset+$NextOffset, $FILE_BEGIN) Then
		_DebugOut("SetFilePointerEx error on offset " & $RCRDOffset+$NextOffset & @CRLF)
		Exit
	EndIf
	If Not _WinAPI_ReadFile($hFile, DllStructGetPtr($rBuffer), $RCRD_Size, $nBytes) Then
		_DebugOut("ReadFile error on offset " & $RCRDOffset+$NextOffset & @CRLF)
		Exit
	EndIf
	$DataChunk = DllStructGetData($rBuffer, 1)

	If StringMid($DataChunk,3,8) <> $RCRDsig Then
		_DebugOut("Error: This should not happen" & @CRLF)
		_DebugOut("Look up 0x" & Hex(Int($RCRDOffset+$NextOffset)) & @CRLF)
		_DebugOut(_HexEncode($DataChunk) & @CRLF)
		$NextOffset += 1
		ContinueLoop
	EndIf

	If Not _ValidateIndxStructureWithFixups($DataChunk) Then ; Test failed. Trying to validate RCRD structure without caring for fixups
		If Not _ValidateIndxStructureWithoutFixups($DataChunk) Then ; RCRD structure seems bad. False positive
			$ErrorCode = @error
			_DebugOut("False positive at 0x" & Hex(Int($RCRDOffset+$NextOffset)) & " ErrorCode: " & $ErrorCode)
			$FalsePositivesCounter+=1
			$NextOffset += $RCRDOffset + 1
			$Written = _WinAPI_WriteFile($hFileOutFalsePositives, DllStructGetPtr($rBuffer), $RCRD_Size, $nBytes)
			If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileFalsePositives & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
			ContinueLoop
		Else ; RCRD structure could be validated, although fixups failed. This record may be from memory dump.
			$Written = _WinAPI_WriteFile($hFileOutWithoutFixups, DllStructGetPtr($rBuffer), $RCRD_Size, $nBytes)
			If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileWithoutFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
			$RecordsWithoutFixupsCounter+=1
		EndIf
	Else ; Fixups successfully verified and RCRD structure seems fine.
		$Written = _WinAPI_WriteFile($hFileOutWithFixups, DllStructGetPtr($rBuffer), $RCRD_Size, $nBytes)
		If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileWithFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
		$RecordsWithFixupsCounter+=1
	EndIf

	$NextOffset += $RCRDOffset + $RCRD_Size
Until $NextOffset >= $FileSize

_DebugOut("Job took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)))
_DebugOut("Found records with fixups applied: " & $RecordsWithFixupsCounter)
_DebugOut("Found records where fixups failed: " & $RecordsWithoutFixupsCounter)
_DebugOut("False positives: " & $FalsePositivesCounter)

_WinAPI_CloseHandle($hFile)
_WinAPI_CloseHandle($hFileOutWithFixups)
_WinAPI_CloseHandle($hFileOutWithoutFixups)
_WinAPI_CloseHandle($hFileOutFalsePositives)

FileClose($logfile)
If FileGetSize($OutFileWithFixups) = 0 Then FileDelete($OutFileWithFixups)
If FileGetSize($OutFileWithoutFixups) = 0 Then FileDelete($OutFileWithoutFixups)
If FileGetSize($OutFileFalsePositives) = 0 Then FileDelete($OutFileFalsePositives)
Exit

Func _SwapEndian($iHex)
	Return StringMid(Binary(Dec($iHex,2)),3, StringLen($iHex))
EndFunc

Func _HexEncode($bInput)
    Local $tInput = DllStructCreate("byte[" & BinaryLen($bInput) & "]")
    DllStructSetData($tInput, 1, $bInput)
    Local $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", 0, _
            "dword*", 0)

    If @error Or Not $a_iCall[0] Then
        Return SetError(1, 0, "")
    EndIf
    Local $iSize = $a_iCall[5]
    Local $tOut = DllStructCreate("char[" & $iSize & "]")
    $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", DllStructGetPtr($tOut), _
            "dword*", $iSize)
    If @error Or Not $a_iCall[0] Then
        Return SetError(2, 0, "")
    EndIf
    Return SetError(0, 0, DllStructGetData($tOut, 1))
EndFunc  ;==>_HexEncode

Func _DebugOut($text, $var="")
   If $var Then $var = _HexEncode($var) & @CRLF
   $text &= @CRLF & $var
   ConsoleWrite($text)
   If $logfile Then FileWrite($logfile, $text)
EndFunc

Func _ValidateIndxStructureWithFixups($Entry)
	Local $MaxLoops=100, $LocalCounter=0
	$UpdSeqArrOffset = ""
	$UpdSeqArrSize = ""
	$UpdSeqArrOffset = StringMid($Entry, 11, 4)
	$UpdSeqArrOffset = Dec(_SwapEndian($UpdSeqArrOffset),2)
	If $UpdSeqArrOffset <> 40 Then Return 0
	$UpdSeqArrSize = StringMid($Entry, 15, 4)
	$UpdSeqArrSize = Dec(_SwapEndian($UpdSeqArrSize),2)
	$UpdSeqArr = StringMid($Entry, 3 + ($UpdSeqArrOffset * 2), $UpdSeqArrSize * 2 * 2)
	If $RCRD_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($Entry,1023,4)
		Local $RecordEnd2 = StringMid($Entry,2047,4)
		Local $RecordEnd3 = StringMid($Entry,3071,4)
		Local $RecordEnd4 = StringMid($Entry,4095,4)
		Local $RecordEnd5 = StringMid($Entry,5119,4)
		Local $RecordEnd6 = StringMid($Entry,6143,4)
		Local $RecordEnd7 = StringMid($Entry,7167,4)
		Local $RecordEnd8 = StringMid($Entry,8191,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 OR $UpdSeqArrPart0 <> $RecordEnd3 OR $UpdSeqArrPart0 <> $RecordEnd4 OR $UpdSeqArrPart0 <> $RecordEnd5 OR $UpdSeqArrPart0 <> $RecordEnd6 OR $UpdSeqArrPart0 <> $RecordEnd7 OR $UpdSeqArrPart0 <> $RecordEnd8 Then
			Return 0
		EndIf
		$Entry =  StringMid($Entry,1,1022) & $UpdSeqArrPart1 & StringMid($Entry,1027,1020) & $UpdSeqArrPart2 & StringMid($Entry,2051,1020) & $UpdSeqArrPart3 & StringMid($Entry,3075,1020) & $UpdSeqArrPart4 & StringMid($Entry,4099,1020) & $UpdSeqArrPart5 & StringMid($Entry,5123,1020) & $UpdSeqArrPart6 & StringMid($Entry,6147,1020) & $UpdSeqArrPart7 & StringMid($Entry,7171,1020) & $UpdSeqArrPart8
	EndIf
	$LocalOffset = 3

	$last_lsn = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+16,16)),2)
;	ConsoleWrite("$last_lsn: " & $last_lsn & @crlf)
	If $last_lsn = 0 Then Return SetError(1,0,0)

	$page_flags = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+32,8)),2)
;	ConsoleWrite("$page_flags: " & $page_flags & @crlf)
	If $page_flags <> 0 And $page_flags <> 1 And $page_flags <> 3 And $page_flags <> 4294967295 Then Return SetError(2,0,0)

	$page_count = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+40,4)),2)
;	ConsoleWrite("$page_count: " & $page_count & @crlf)
	If $page_count = 65535 Then Return SetError(3,0,0)

	$page_position = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+44,4)),2)
;	ConsoleWrite("$page_position: " & $page_position & @crlf)
	If $page_position = 65535 Then Return SetError(4,0,0)

	$next_record_offset = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+48,4)),2)
;	ConsoleWrite("$next_record_offset: " & $next_record_offset & @crlf)
	If $next_record_offset > 0x1000 Then Return SetError(5,0,0)
	If Mod($next_record_offset,8) Then Return SetError(5,0,0)

	;$page_unknown = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+52,12)),2)
	$page_unknown = StringMid($Entry,$LocalOffset+52,12)
;	ConsoleWrite("$page_unknown: " & $page_unknown & @crlf)
	If $page_unknown <> "000000000000" And $page_unknown <> "FFFFFFFFFFFF" Then Return SetError(6,0,0)

;	$last_end_lsn = Dec(StringMid($Entry,$LocalOffset+64,16),2)

;	$UpdateSequenceArray = Dec(StringMid($Entry,$LocalOffset+80,36),2)

;	$LastPartPadding = Dec(StringMid($Entry,$LocalOffset+116,12),2)
;	If $LastPartPadding <> 0 Then Return SetError(7,0,0)

	Return 1
EndFunc

Func _ValidateIndxStructureWithoutFixups($Entry)
	Local $MaxLoops=100, $LocalCounter=0

	$LocalOffset = 3

	$last_lsn = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+16,16)),2)
;	ConsoleWrite("$last_lsn: " & $last_lsn & @crlf)
	If $last_lsn = 0 Then Return SetError(1,0,0)

	$page_flags = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+32,8)),2)
;	ConsoleWrite("$page_flags: " & $page_flags & @crlf)
	If $page_flags <> 0 And $page_flags <> 1 And $page_flags <> 3 And $page_flags <> 4294967295 Then Return SetError(2,0,0)

	$page_count = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+40,4)),2)
;	ConsoleWrite("$page_count: " & $page_count & @crlf)
	If $page_count = 65535 Then Return SetError(3,0,0)

	$page_position = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+44,4)),2)
;	ConsoleWrite("$page_position: " & $page_position & @crlf)
	If $page_position = 65535 Then Return SetError(4,0,0)

	$next_record_offset = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+48,4)),2)
;	ConsoleWrite("$next_record_offset: " & $next_record_offset & @crlf)
	If $next_record_offset > 0x1000 Then Return SetError(5,0,0)
	If Mod($next_record_offset,8) Then Return SetError(5,0,0)

	;$page_unknown = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+52,12)),2)
	$page_unknown = StringMid($Entry,$LocalOffset+52,12)
;	ConsoleWrite("$page_unknown: " & $page_unknown & @crlf)
	If $page_unknown <> "000000000000" And $page_unknown <> "FFFFFFFFFFFF" Then Return SetError(6,0,0)

;	$last_end_lsn = Dec(StringMid($Entry,$LocalOffset+64,16),2)

;	$UpdateSequenceArray = Dec(StringMid($Entry,$LocalOffset+80,36),2)

;	$LastPartPadding = Dec(StringMid($Entry,$LocalOffset+116,12),2)
;	If $LastPartPadding <> 0 Then Return SetError(7,0,0)

	Return 1
EndFunc

Func _GetInputParams()

	For $i = 1 To $cmdline[0]
		;ConsoleWrite("Param " & $i & ": " & $cmdline[$i] & @CRLF)
		If StringLeft($cmdline[$i],11) = "/InputFile:" Then $File = StringMid($cmdline[$i],12)
		If StringLeft($cmdline[$i],12) = "/OutputPath:" Then $OutputPath = StringMid($cmdline[$i],13)
	Next

	If $File="" Then ;No InputFile parameter passed
		$File = FileOpenDialog("Select file",@ScriptDir,"All (*.*)")
		If @error Then Exit
	ElseIf FileExists($File) = 0 Then
		ConsoleWrite("Input file does not exist: " & $cmdline[1] & @CRLF)
		$File = FileOpenDialog("Select file",@ScriptDir,"All (*.*)")
		If @error Then Exit
	EndIf

	If StringLen($OutputPath) > 0 Then
		If Not FileExists($OutputPath) Then
			ConsoleWrite("Error input $OutputPath does not exist. Setting default to program directory." & @CRLF)
			$OutputPath = @ScriptDir
		EndIf
	Else
		$OutputPath = @ScriptDir
	EndIf

EndFunc