# imview

ADM WAVE File Viewer/Inspector

## Work-in-Progress

This project is a work-in-progress. Behavior and features may change often
and without notice.

## Examples

### Print Track List and Roles 

```sh 
$ imview tracks test_audio/adm.wav
Trk 1 ATU_00000001 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricLeft" 
Trk 2 ATU_00000002 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricRight" 
Trk 3 ATU_00000003 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricCenter" 
Trk 4 ATU_00000004 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricLFE" 
Trk 5 ATU_00000005 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricLeftSideSurround" 
Trk 6 ATU_00000006 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricRightSideSurround" 
Trk 7 ATU_00000007 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricLeftRearSurround" 
Trk 8 ATU_00000008 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricRightRearSurround" 
Trk 9 ATU_00000009 "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricLeftTopSurround" 
Trk 10 ATU_0000000a "DIAL" "Bed 1-10" "DirectSpeakers" "RoomCentricRightTopSurround" 
Trk 11 ATU_0000000b "DIAL" "Object 11" "Objects" "Atmos_Obj_1" 
Trk 12 ATU_0000000c "MX" "Object 12" "Objects" "Atmos_Obj_2" 
Trk 13 ATU_0000000d "FX" "Object 13" "Objects" "Atmos_Obj_3" 
Trk 14 ATU_0000000e "FX" "Object 14" "Objects" "Atmos_Obj_4" 
```

### Print AudioProgramme Tree

```sh 
$ imview program test_audio/adm.wav
AudioProgramme (APR_1001) "Atmos_Master"
 + AudioContent (ACO_1001) "DIAL"
   -> AudioObject (AO_1001) "Bed 1-10" (AudioTrackUID count 10)
     + AudioPackFormat (AP_00011001) "AtmosCustomPackFormat1" (type: "DirectSpeakers")
       + AudioChannelFormat (AC_00011001) "RoomCentricLeft"
         -> AudioStreamFormat (AS_00011001)
         -> AudioTrackFormat (AT_00011001_01)
         => AudioTrackUID (ATU_00000001) [index 1]
       + AudioChannelFormat (AC_00011002) "RoomCentricRight"
         -> AudioStreamFormat (AS_00011002)
         -> AudioTrackFormat (AT_00011002_01)
         => AudioTrackUID (ATU_00000002) [index 2]
       + AudioChannelFormat (AC_00011003) "RoomCentricCenter"
         -> AudioStreamFormat (AS_00011003)
         -> AudioTrackFormat (AT_00011003_01)
         => AudioTrackUID (ATU_00000003) [index 3]
       + AudioChannelFormat (AC_00011004) "RoomCentricLFE"
         -> AudioStreamFormat (AS_00011004)
         -> AudioTrackFormat (AT_00011004_01)
         => AudioTrackUID (ATU_00000004) [index 4]
       + AudioChannelFormat (AC_00011005) "RoomCentricLeftSideSurround"
         -> AudioStreamFormat (AS_00011005)
         -> AudioTrackFormat (AT_00011005_01)
         => AudioTrackUID (ATU_00000005) [index 5]
       + AudioChannelFormat (AC_00011006) "RoomCentricRightSideSurround"
         -> AudioStreamFormat (AS_00011006)
         -> AudioTrackFormat (AT_00011006_01)
         => AudioTrackUID (ATU_00000006) [index 6]
       + AudioChannelFormat (AC_00011007) "RoomCentricLeftRearSurround"
         -> AudioStreamFormat (AS_00011007)
         -> AudioTrackFormat (AT_00011007_01)
         => AudioTrackUID (ATU_00000007) [index 7]
       + AudioChannelFormat (AC_00011008) "RoomCentricRightRearSurround"
         -> AudioStreamFormat (AS_00011008)
         -> AudioTrackFormat (AT_00011008_01)
         => AudioTrackUID (ATU_00000008) [index 8]
       + AudioChannelFormat (AC_00011009) "RoomCentricLeftTopSurround"
         -> AudioStreamFormat (AS_00011009)
         -> AudioTrackFormat (AT_00011009_01)
         => AudioTrackUID (ATU_00000009) [index 9]
       + AudioChannelFormat (AC_0001100a) "RoomCentricRightTopSurround"
         -> AudioStreamFormat (AS_0001100a)
         -> AudioTrackFormat (AT_0001100a_01)
         => AudioTrackUID (ATU_0000000a) [index 10]
   -> AudioObject (AO_100b) "Object 11" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031001) "Atmos_Obj_1" (type: "Objects")
       + AudioChannelFormat (AC_00031001) "Atmos_Obj_1"
         -> AudioStreamFormat (AS_00031001)
         -> AudioTrackFormat (AT_00031001_01)
         => AudioTrackUID (ATU_0000000b) [index 11]
 + AudioContent (ACO_1002) "MX"
   -> AudioObject (AO_100c) "Object 12" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031002) "Atmos_Obj_2" (type: "Objects")
       + AudioChannelFormat (AC_00031002) "Atmos_Obj_2"
         -> AudioStreamFormat (AS_00031002)
         -> AudioTrackFormat (AT_00031002_01)
         => AudioTrackUID (ATU_0000000c) [index 12]
 + AudioContent (ACO_1003) "FX"
   -> AudioObject (AO_100d) "Object 13" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031003) "Atmos_Obj_3" (type: "Objects")
       + AudioChannelFormat (AC_00031003) "Atmos_Obj_3"
         -> AudioStreamFormat (AS_00031003)
         -> AudioTrackFormat (AT_00031003_01)
         => AudioTrackUID (ATU_0000000d) [index 13]
   -> AudioObject (AO_100e) "Object 14" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031004) "Atmos_Obj_4" (type: "Objects")
       + AudioChannelFormat (AC_00031004) "Atmos_Obj_4"
         -> AudioStreamFormat (AS_00031004)
         -> AudioTrackFormat (AT_00031004_01)
         => AudioTrackUID (ATU_0000000e) [index 14]
```
