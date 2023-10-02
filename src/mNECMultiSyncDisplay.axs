MODULE_NAME='mNECMultiSyncDisplay'      (
                                            dev vdvObject,
                                            dev vdvControl
                                        )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.Math.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE = 1

constant integer REQUIRED_POWER_ON    = 1
constant integer REQUIRED_POWER_OFF    = 2

constant integer ACTUAL_POWER_ON    = 1
constant integer ACTUAL_POWER_OFF    = 2

constant integer REQUIRED_INPUT_VGA_1    = 1
constant integer REQUIRED_INPUT_RGB_1    = 2
constant integer REQUIRED_INPUT_DVI_1    = 3
constant integer REQUIRED_INPUT_VIDEO_1    = 4
constant integer REQUIRED_INPUT_VIDEO_2    = 5
constant integer REQUIRED_INPUT_SVIDEO_1    = 6
constant integer REQUIRED_INPUT_TV_1    = 7
constant integer REQUIRED_INPUT_COMPONENT_1    = 8
constant integer REQUIRED_INPUT_OPTION_1    = 9
constant integer REQUIRED_INPUT_COMPONENT_2    = 10
constant integer REQUIRED_INPUT_DISPLAYPORT_1    = 11
constant integer REQUIRED_INPUT_HDMI_1    = 12

constant integer ACTUAL_INPUT_VGA_1    = 1
constant integer ACTUAL_INPUT_RGB_1    = 2
constant integer ACTUAL_INPUT_DVI_1    = 3
constant integer ACTUAL_INPUT_VIDEO_1    = 4
constant integer ACTUAL_INPUT_VIDEO_2    = 5
constant integer ACTUAL_INPUT_SVIDEO_1    = 6
constant integer ACTUAL_INPUT_TV_1    = 7
constant integer ACTUAL_INPUT_COMPONENT_1    = 8
constant integer ACTUAL_INPUT_OPTION_1    = 9
constant integer ACTUAL_INPUT_COMPONENT_2    = 10
constant integer ACTUAL_INPUT_DISPLAYPORT_1    = 11
constant integer ACTUAL_INPUT_HDMI_1    = 12

constant integer REQUIRED_MUTE_ON    = 1
constant integer REQUIRED_MUTE_OFF    = 2

constant integer ACTUAL_MUTE_ON    = 1
constant integer ACTUAL_MUTE_OFF    = 2

constant integer GET_POWER    = 1
constant integer GET_INPUT    = 2
constant integer GET_MUTE    = 3
constant integer GET_VOLUME    = 4


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long ltDrive[] = { 200 }

volatile integer iLoop

volatile _NAVDisplay uDisplay

volatile char cUnitID[] = '1'

volatile integer iID

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iCommandLockOut

volatile integer iPollSequence = GET_POWER

volatile integer iRegistered
volatile integer iRegisterReady = true
volatile integer iRegisterRequested


(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendCommand(char cParam[]) {
    NAVLog("'Command to ',NAVStringSurroundWith(NAVDeviceToString(vdvControl), '[', ']'),': [',cParam,']'")
    send_command vdvControl,"cParam"
}

define_function BuildCommand(char cHeader[], char cCmd[]) {
    if (length_array(cCmd)) {
    SendCommand("cHeader,'-<',itoa(iID),'|',cCmd,'>'")
    }else {
    SendCommand("cHeader,'-<',itoa(iID),'>'")
    }
}

define_function Register() {
    iRegistered = true
    if (iID) { BuildCommand('REGISTER','') }
    NAVLog("'NEC_REGISTER<',itoa(iID),'>'")
}

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,'>')) {
    cTemp = remove_string(cRxBuffer,"'>'",1)
    if (length_array(cTemp)) {
        NAVLog("'Parsing String From ',NAVStringSurroundWith(NAVDeviceToString(vdvControl), '[', ']'),': [',cTemp,']'")
        if (NAVContains(cRxBuffer, cTemp)) { cRxBuffer = "''" }
        select {
        active (NAVStartsWith(cTemp,'REGISTER')): {
            iID = atoi(NAVGetStringBetween(cTemp,'<','>'))
            //if (iID) { BuildCommand('REGISTER','') }
            NAVLog("'NEC_REGISTER_REQUESTED<',itoa(iID),'>'")

            iRegisterRequested = true
            if (iRegisterReady) {
            Register()
            }
        }
        active (NAVStartsWith(cTemp,'INIT')): {
            //if (cUnitGroup == '*' || cUnitID == '*') {
            //if (!iIsInitialized) {
                //iIsInitialized = true
                //BuildCommand('INIT_DONE','')
            //}
           // }else {
            module.Device.IsInitialized = false
            GetInitialized()
            NAVLog("'NEC_INIT_REQUESTED<',itoa(iID),'>'")

            //}
        }
        active (NAVStartsWith(cTemp,'START_POLLING')): {
            timeline_create(TL_DRIVE,ltDrive,length_array(ltDrive),TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
        }
        active (NAVStartsWith(cTemp,'RESPONSE_MSG')): {
            stack_var char cResponseRequestMess[NAV_MAX_BUFFER]
            stack_var char cResponseMess[NAV_MAX_BUFFER]
            //NAVLog("'RESPONCE_MSG_RECEIVED<',itoa(iID),'>: ',cTemp")
            TimeOut()
            cResponseRequestMess = NAVGetStringBetween(cTemp,'<','|')
            cResponseMess = NAVGetStringBetween(cTemp,'|','>')
            BuildCommand('RESPONSE_OK',cResponseRequestMess)
            select {
            active (NAVContains(cResponseMess,'D6000004000')): {
                remove_string(cResponseMess,'D6000004000',1)
                switch (cResponseMess) {
                case '1': { uDisplay.PowerState.Actual = ACTUAL_POWER_ON }
                case '2': { uDisplay.PowerState.Actual = ACTUAL_POWER_ON }
                case '3': { uDisplay.PowerState.Actual = ACTUAL_POWER_ON }
                case '4': { uDisplay.PowerState.Actual = ACTUAL_POWER_OFF }
                }

                iPollSequence = GET_INPUT
            }
            active (NAVContains(cResponseMess,'6000001100')): {
                stack_var integer iTemp
                remove_string(cResponseMess,'6000001100',1)
                switch (cResponseMess) {
                case '01': { uDisplay.Input.Actual = ACTUAL_INPUT_VGA_1 }
                case '02': { uDisplay.Input.Actual = ACTUAL_INPUT_RGB_1 }
                case '03': { uDisplay.Input.Actual = ACTUAL_INPUT_DVI_1 }
                case '05': { uDisplay.Input.Actual = ACTUAL_INPUT_VIDEO_1 }
                case '06': { uDisplay.Input.Actual = ACTUAL_INPUT_VIDEO_2 }
                case '07': { uDisplay.Input.Actual = ACTUAL_INPUT_SVIDEO_1 }
                case '0A': { uDisplay.Input.Actual = ACTUAL_INPUT_TV_1 }
                case '0C': { uDisplay.Input.Actual = ACTUAL_INPUT_COMPONENT_1 }
                case '0D': { uDisplay.Input.Actual = ACTUAL_INPUT_OPTION_1 }
                case '0E': { uDisplay.Input.Actual = ACTUAL_INPUT_COMPONENT_2 }
                case '0F': { uDisplay.Input.Actual = ACTUAL_INPUT_DISPLAYPORT_1 }
                case '11': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_1 }
                }

                if (!module.Device.IsInitialized) {
                module.Device.IsInitialized = true
                BuildCommand('INIT_DONE','')
                //NAVLog("'INIT_DONE<',itoa(iID),'>'")
                NAVLog("'NEC_INIT_DONE<',itoa(iID),'>'")
                //timeline_create(TL_DRIVE,ltDrive,length_array(ltDrive),TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
                }

                iPollSequence = GET_POWER
            }
            active (NAVContains(cResponseMess,'8D000002000')): {
                remove_string(cResponseMess,'8D000002000',1)
                switch (cResponseMess) {
                case '0': { uDisplay.Volume.Mute.Actual = ACTUAL_MUTE_OFF; }
                case '1': { uDisplay.Volume.Mute.Actual = ACTUAL_MUTE_ON; }
                case '2': { uDisplay.Volume.Mute.Actual = ACTUAL_MUTE_OFF; }
                }

                iPollSequence = GET_VOLUME
            }
            active (NAVContains(cResponseMess,'6200006400')): {
                stack_var sinteger siTemp
                remove_string(cResponseMess,'6200006400',1)
                siTemp = hextoi(cResponseMess)
                if (siTemp <> uDisplay.Volume.Level.Actual) {
                uDisplay.Volume.Level.Actual = siTemp
                send_level vdvObject,1,NAVScaleValue(uDisplay.Volume.Level.Actual,100,255,0)
                }

                if (!module.Device.IsInitialized) {
                module.Device.IsInitialized = true
                BuildCommand('INIT_DONE','')
                //NAVLog("'INIT_DONE<',itoa(iID),'>'")
                NAVLog("'NEC_INIT_DONE<',itoa(iID),'>'")
                //timeline_create(TL_DRIVE,ltDrive,length_array(ltDrive),TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
                }

                iPollSequence = GET_POWER
            }
            }
        }
        }
    }
    }

    iSemaphore = false
}

define_function GetInitialized() {
    SendQuery(GET_POWER)
    SendQuery(GET_INPUT)
    //SendQuery(GET_MUTE)
    //SendQuery(GET_VOLUME)
}


define_function SendQuery(integer iParam) {
    switch (iParam) {
    case GET_POWER: { BuildCommand('POLL_MSG',"'0',atoi(cUnitID) + $40,'0A06',NAV_STX,'01D6',NAV_ETX") }
    case GET_INPUT: { BuildCommand('POLL_MSG',"'0',atoi(cUnitID) + $40,'0C06',NAV_STX,'0060',NAV_ETX") }
    //case GET_MUTE: { BuildCommand('POLL_MSG',"'0',atoi(cUnitID) + $40,'0C06',NAV_STX,'008D',NAV_ETX") }
    //case GET_VOLUME: { BuildCommand('POLL_MSG',"'0',atoi(cUnitID) + $40,'0C06',NAV_STX,'0062',NAV_ETX") }
    }
}

define_function TimeOut() {
    module.Device.IsCommunicating = true
    cancel_wait 'CommsTimeOut'
    wait 300 'CommsTimeOut' { module.Device.IsCommunicating = false }
}

define_function SetPower(integer iParam) {
    switch (iParam) {
    case REQUIRED_POWER_ON: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0A0C',NAV_STX,'C203D60001',NAV_ETX") }
    case REQUIRED_POWER_OFF: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0A0C',NAV_STX,'C203D60004',NAV_ETX") }
    }
}

define_function SetInput(integer iParam) {
    switch (iParam) {
    case REQUIRED_INPUT_VGA_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600001',NAV_ETX") }
    case REQUIRED_INPUT_RGB_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600002',NAV_ETX") }
    case REQUIRED_INPUT_DVI_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600003',NAV_ETX") }
    case REQUIRED_INPUT_VIDEO_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600005',NAV_ETX") }
    case REQUIRED_INPUT_VIDEO_2: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600006',NAV_ETX") }
    case REQUIRED_INPUT_SVIDEO_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600007',NAV_ETX") }
    case REQUIRED_INPUT_TV_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'0060000A',NAV_ETX") }
    case REQUIRED_INPUT_COMPONENT_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'0060000C',NAV_ETX") }
    case REQUIRED_INPUT_OPTION_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'0060000D',NAV_ETX") }
    case REQUIRED_INPUT_COMPONENT_2: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'0060000E',NAV_ETX") }
    case REQUIRED_INPUT_DISPLAYPORT_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'0060000F',NAV_ETX") }
    case REQUIRED_INPUT_HDMI_1: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'00600011',NAV_ETX") }
    }
}

define_function SetMute(integer iParam) {
    switch (iParam) {
    case REQUIRED_MUTE_ON: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'008D0001',NAV_ETX") }
    case REQUIRED_MUTE_OFF: { BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'008D0002',NAV_ETX") }
    }
}

define_function SetVolume(sinteger siParam) {
    BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'006200',format('%02X',siParam),NAV_ETX")
}


define_function Drive() {
    iLoop++
    switch (iLoop) {
    case 1:
    case 81:
    case 161:
    case 241: { SendQuery(iPollSequence); return }
    case 321: { iLoop = 0; return }
    default: {
        if (iCommandLockOut) { return }
        if (uDisplay.PowerState.Required && (uDisplay.PowerState.Required == uDisplay.PowerState.Actual)) { uDisplay.PowerState.Required = 0; return }
        if (uDisplay.Input.Required && (uDisplay.Input.Required == uDisplay.Input.Actual)) { uDisplay.Input.Required = 0; return }
        if (uDisplay.Volume.Mute.Required && (uDisplay.Volume.Mute.Required == uDisplay.Volume.Mute.Actual)) { uDisplay.Volume.Mute.Required = 0; return }
        if (uDisplay.Volume.Level.Required >= 0 && (uDisplay.Volume.Level.Required == uDisplay.Volume.Level.Actual)) { uDisplay.Volume.Level.Required = -1; return }

        if (uDisplay.Volume.Mute.Required && (uDisplay.Volume.Mute.Required <> uDisplay.Volume.Mute.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
        SetMute(uDisplay.Volume.Mute.Required)
        iCommandLockOut = true
        wait 20 iCommandLockOut = false
        iPollSequence = GET_MUTE
        return
        }

        if (uDisplay.PowerState.Required && (uDisplay.PowerState.Required <> uDisplay.PowerState.Actual) && module.Device.IsCommunicating) {
        SetPower(uDisplay.PowerState.Required)
        iCommandLockOut = true
        wait 80 iCommandLockOut = false
        iPollSequence = GET_POWER
        iLoop = 0    //Force a poll
        return
        }

        if (uDisplay.Input.Required && (uDisplay.Input.Required  <> uDisplay.Input.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
        SetInput(uDisplay.Input.Required)
        iCommandLockOut = true
        wait 20 iCommandLockOut = false
        iPollSequence = GET_INPUT
        return
        }

        /*
        if ([vdvObject,VOL_UP] && uDisplay.PowerState.Actual == ACTUAL_POWER_ON) { uDisplay.Volume.Level.Required++ }
        if ([vdvObject,VOL_DN] && uDisplay.PowerState.Actual == ACTUAL_POWER_ON) { uDisplay.Volume.Level.Required-- }

        if (uDisplay.Volume.Level.Required && (uDisplay.Volume.Level.Required <> uDisplay.Volume.Level.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
        SetVolume(uDisplay.Volume.Level.Required)
        iCommandLockOut = true
        wait 5 iCommandLockOut = false
        iPollSequence = GET_VOLUME
        return
        }
        */

        if (uDisplay.AutoAdjustRequired && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
        BuildCommand('COMMAND_MSG',"'0',atoi(cUnitID) + $40,'0E0A',NAV_STX,'001E0001',NAV_ETX")
        uDisplay.AutoAdjustRequired = 0
        return
        }
    }
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer vdvControl,cRxBuffer
    uDisplay.Volume.Level.Required = -1
    uDisplay.Volume.Level.Actual = -1
}
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[vdvControl] {
    string: {
    //NAVLog("'NEC_STRING_COMM_MODULE<',data.text,'>'")
    if (!iSemaphore) {
        Process()
    }
    }
}

data_event[vdvObject] {
    online: {
    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Monitor'")
    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.nec.com'")
    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,NEC'")
    }
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
    stack_var char cCmdParam[2][NAV_MAX_CHARS]
    NAVLog("'Command from ',NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'),': [',data.text,']'")
    cCmdHeader = DuetParseCmdHeader(data.text)
    cCmdParam[1] = DuetParseCmdParam(data.text)
    cCmdParam[2] = DuetParseCmdParam(data.text)
    switch (cCmdHeader) {
        case 'PROPERTY': {
        switch (cCmdParam[1]) {
            case 'UNIT_ID': {
            cUnitID = cCmdParam[2]
            }
        }
        }
        case 'ADJUST': {}
        case 'VOLUME': {
        switch (cCmdParam[1]) {
            case 'ABS': {
            uDisplay.Volume.Level.Required = atoi(cCmdParam[2]); Drive();
            SetVolume(uDisplay.Volume.Level.Required);
            }
            default: {
            uDisplay.Volume.Level.Required = NAVScaleValue(atoi(cCmdParam[1]),255,(100 - 0),0); Drive();
            SetVolume(uDisplay.Volume.Level.Required);
            }
        }
        }
        case 'POWER': {
        switch (cCmdParam[1]) {
            case 'ON': {
            uDisplay.PowerState.Required = REQUIRED_POWER_ON; Drive()
            }
            case 'OFF': {
            uDisplay.PowerState.Required = REQUIRED_POWER_OFF; uDisplay.Input.Required = 0; Drive()
            }
        }
        }
        case 'INPUT': {
        switch (cCmdParam[1]) {
            case 'VGA': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_VGA_1; Drive() }
            }
            }
            case 'RGB': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_RGB_1; Drive() }
            }
            }
            case 'DVI': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_DVI_1; Drive() }
            }
            }
            case 'COMPOSITE': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_VIDEO_1; Drive() }
                case '2': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_VIDEO_2; Drive() }
            }
            }
            case 'S-VIDEO': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_SVIDEO_1; Drive() }
            }
            }
            case 'TV': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_TV_1; Drive() }
            }
            }
            case 'COMPONENT': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_COMPONENT_1; Drive() }
                case '2': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_COMPONENT_2; Drive() }
            }
            }
            case 'OPTION': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_OPTION_1; Drive() }
            }
            }
            case 'DISPLAYPORT': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_DISPLAYPORT_1; Drive() }
            }
            }
            case 'HDMI': {
            switch (cCmdParam[2]) {
                case '1': { uDisplay.PowerState.Required = REQUIRED_POWER_ON; uDisplay.Input.Required = REQUIRED_INPUT_HDMI_1; Drive() }
            }
            }
        }
        }
    }
    }
}

define_event channel_event[vdvObject,0] {
    on: {
    switch (channel.channel) {
        case PWR_ON: {
        uDisplay.PowerState.Required = REQUIRED_POWER_ON; Drive()
        }
        case PWR_OFF: {
        uDisplay.PowerState.Required = REQUIRED_POWER_OFF; uDisplay.Input.Required = 0; Drive()
        }
    }
    }
    off: {

    }
}

timeline_event[TL_DRIVE] { Drive(); }

timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, POWER_FB]    = (uDisplay.PowerState.Actual == ACTUAL_POWER_ON)
    [vdvObject, DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject, DATA_INITIALIZED] = (module.Device.IsInitialized)
    [vdvObject, VOL_MUTE_FB]    = (uDisplay.Volume.Mute.Actual == ACTUAL_MUTE_ON)
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

