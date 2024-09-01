%% MRBreach
% Application to compute the breach dimensions required for a Managed
% Realignment site.##

%% Licence
% The code is provided as Open Source code (issued under a GNU General 
% Public License).

%% Requirements
% MRBreach is written in Matlab(TM) and requires v2016b, or later. In addition, 
% MRBreach requires both the <matlab:doc('dstoolbox') dstoolbox> and the 
% <matlab:doc('muitoolbox') muitoolbox>

%% Background
% MRBreach is a utility to support the design of the sort of breach in a sea 
% wall that is commonly required for managed realignment schemes. These 
% schemes aim to increase the area of intertidal by allowing the sea back 
% into areas of land that have been protected by sea defences in the past. 
% It is usually impractical to remove the entire sea wall. There is therefore 
% a need to determine the size of breach required to allow tidal exchange 
% into and out of the site. In such design there is also the practical 
% consideration of being able to construct the breach safely, in the time 
% available over a tidal cycle. This piece of software implements a method 
% proposed for the design of such breaches based on creating one, or more, 
% stable channels into the site. 

%% MRBreach classes
% * *MRBreach* - defines the behaviour of the main UI.
% * *mrSiteData* - handles input of site parameters.
% * *mrBreachData* - handles input of hydraulic parameters.
% * *mrHypsometry* - handles import of measured hypsometry from file and
% computation of empirical 'fitted' hypsometry.
% * *mrBreachModel* - computes breach regime section

%% Manual
% The <matlab:mrb_open_manual manual> provides further details of setup and 
% configuration of the model. The files for the example use case can be found in
% the example folder <matlab:mrb_example_folder here>. 

%% See Also
% <matlab:doc('muitoolbox') muitoolbox>, <matlab:doc('dstoolbox') dstoolbox>.
	