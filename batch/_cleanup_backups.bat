PushD "F:\backups01\full" &&("forfiles.exe" /S /M "*.bak" /D -21 /C "cmd /c del @file") & PopD
PushD "G:\" &&("forfiles.exe" /S /M "*.diff" /D -8 /C "cmd /c del @file") & PopD
PushD "H:\" &&("forfiles.exe" /S /M "*.trn" /D -3 /C "cmd /c del @file") & PopD