classdef mrBreachData < muiPropertyUI 
    %class to manage wind and water level input data for MRBreach model
%
%-------class help---------------------------------------------------------
% NAME
%   mrBreachData.m
% PURPOSE
%   Class to manage wind and water level input data for MRBreach model
% USAGE
%   obj = mrBreachData.setInput(mobj); %mobj is a handle to Main UI
% SEE ALSO
%   inherits muiPropertyUI
%
% Author: Ian Townend
% CoastalSEA (c) Jan 2021
%--------------------------------------------------------------------------
%   
    properties (Hidden)
        PropertyLabels = {'Tidal period (hours)',...
                          'High water level (mOD)',...
                          'Low water level (mOD)',...
                          'Wave-current interaction (0= current only)',...
                          'Wind speed (m/s)',...
                          'Wind level (m)',...
                          'Fetch length (m)',...
                          'Av. depth over fetch (m)'}
        %abstract property in PropertyInterface for tab display definition             
        TabDisplay   %structure defines how the property table is displayed             
    end
    
    properties
        TidalPeriod = 12.4  %tidal period, hours
        zHWlevel            %level of high water, mOD
        zLWlevel            %level of low water, mOD
        wcflg = 1           %flag; currents only=0, wave+current=1
        WindSpeed           %wind speed, ms^-1
        WindLevel = 10      %wind speed elevation, m above ground
        FetchLength         %available fetch length, m
        FetchDepth          %average water depth over fetch, m
    end
%%   
    methods (Access=protected)
        function obj = mrBreachData(mobj) 
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
            classname = 'mrBreachData';           
            if isfield(mobj.Inputs,classname) && ...
                            isa(mobj.Inputs.(classname),classname)
                obj = mobj.Inputs.(classname);  
            else
                obj = mrBreachData(mobj);    
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