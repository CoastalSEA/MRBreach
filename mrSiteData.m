classdef mrSiteData < muiPropertyUI 
%
%-------class help---------------------------------------------------------
% NAME
%   mrSiteData.m
% PURPOSE
%   Class to manage site input data for MRBreachModel
% USAGE
%   obj = mrSiteData.setInput(mobj); %mobj is a handle to Main UI
% SEE ALSO
%   inherits muiPropertyUI
%
% Author: Ian Townend
% CoastalSEA (c) Jan 2021
%--------------------------------------------------------------------------
%  
    properties (Hidden)
        PropertyLabels = {'Tidal Prism (m3)',...
                          'HW Area (m2)',...
                          'LW or lowest site level (mOD)',...
                          'Area at lowest level (m2)',...
                          'Number of breaches',...
                          'd50 sediment size (m)',...
                          'Erosion Threshold (Pa)'}
        TabDisplay   %structure defines how the property table is displayed               
    end
    
    properties
        TidalPrism     %tidal prism (or volume of site), m^3
        HWArea         %surface area of site at high water, m^2
        z0level        %lowest level of site or breach invert level, mOD
        z0Area         %surface area at lowest level of site, m^2        
        nBreaches  = 1 %number of breaches
        d50SedSize     %particle size, m
        EroThreshold   %critical erosion threshold, Pa
    end
%%   
    methods (Access=protected)
        function obj = mrSiteData(mobj)            
            %constructor code:            
            %values defined in UI function setTabProperties used to assign
            %the tabname and position on tab for the data to be displayed
            obj = setTabProps(obj,mobj);  %muiPropertyUI function
        end 
    end
%%  
    methods (Static)  
        function obj = setInput(mobj,editflag)
            %gui for user to set Parameter Input values
            classname = 'mrSiteData';             
            if isfield(mobj.Inputs,classname) && ...
                            isa(mobj.Inputs.(classname),classname)
                obj = mobj.Inputs.(classname);  
            else
                obj = mrSiteData(mobj);            
            end
            %use muiPropertyUI function to generate UI
            if nargin<2 || editflag
                %add nrec to limit length of props UI (default=12)
                obj = editProperties(obj);  
                %add any additional manipulation of the input here
            end
            mobj.Inputs.(classname) = obj;
        end     
    end   
%%     
        %add other functions to operate on properties as required
end