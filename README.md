# imview

ADM WAVE File Viewer/Inspector

## Work-in-Progress

This project is a work-in-progress and is not at this time useable.

## Example

```sh 
$ imview
AudioProgramme (APR_1001) "Atmos_Master"
 + AudioContent (ACO_1001) "DIAL"
   + AudioObject (AO_1001) "Bed 1-10" (AudioTrackUID count 10)
     + AudioPackFormat (AP_00011001) "AtmosCustomPackFormat1" (type: "DirectSpeakers")
       + AudioChannelFormat (AC_00011001) "RoomCentricLeft"
       + AudioChannelFormat (AC_00011002) "RoomCentricRight"
       + AudioChannelFormat (AC_00011003) "RoomCentricCenter"
       + AudioChannelFormat (AC_00011004) "RoomCentricLFE"
       + AudioChannelFormat (AC_00011005) "RoomCentricLeftSideSurround"
       + AudioChannelFormat (AC_00011006) "RoomCentricRightSideSurround"
       + AudioChannelFormat (AC_00011007) "RoomCentricLeftRearSurround"
       + AudioChannelFormat (AC_00011008) "RoomCentricRightRearSurround"
       + AudioChannelFormat (AC_00011009) "RoomCentricLeftTopSurround"
       + AudioChannelFormat (AC_0001100a) "RoomCentricRightTopSurround"
   + AudioObject (AO_100b) "Object 11" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031001) "Atmos_Obj_1" (type: "Objects")
       + AudioChannelFormat (AC_00031001) "Atmos_Obj_1"
 + AudioContent (ACO_1002) "MX"
   + AudioObject (AO_100c) "Object 12" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031002) "Atmos_Obj_2" (type: "Objects")
       + AudioChannelFormat (AC_00031002) "Atmos_Obj_2"
 + AudioContent (ACO_1003) "FX"
   + AudioObject (AO_100d) "Object 13" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031003) "Atmos_Obj_3" (type: "Objects")
       + AudioChannelFormat (AC_00031003) "Atmos_Obj_3"
   + AudioObject (AO_100e) "Object 14" (AudioTrackUID count 1)
     + AudioPackFormat (AP_00031004) "Atmos_Obj_4" (type: "Objects")
       + AudioChannelFormat (AC_00031004) "Atmos_Obj_4"
```
