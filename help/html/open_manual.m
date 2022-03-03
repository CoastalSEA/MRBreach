function open_manual()
%find the location of the asmita app and open the manual
appinfo = matlab.apputil.getInstalledAppInfo;
idx = find(strcmp({appinfo.name},'MRBreach'));
fpath = [appinfo(idx(1)).location,[filesep,'doc',filesep,'MRBreach manual.pdf']];
open(fpath)
