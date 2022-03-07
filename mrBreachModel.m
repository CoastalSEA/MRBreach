classdef mrBreachModel < muiDataSet                         
%
%-------class help---------------------------------------------------------
% NAME
%   mrBreachModel.m
% PURPOSE
%   Class for MRBreach model to be run as a muitoolbox App
% SEE ALSO
%   muiDataSet
%
% Author: Ian Townend
% CoastalSEA (c) Oct 2021
%--------------------------------------------------------------------------
%     
    properties
        %inherits Data, RunParam, MetaData and CaseIndex from muiDataSet
        %Additional properties:     
        WidthVals = []            %structure for width values   
    end
    
    methods (Access = private)
        function obj = mrBreachModel()                     
            %class constructor
        end
    end      
%%
    methods (Static)        
%--------------------------------------------------------------------------
% Model implementation
%--------------------------------------------------------------------------         
        function obj = runModel(mobj)
            %function to run a simple 2D diffusion model
            obj = mrBreachModel;                           
            dsp = modelDSproperties(obj);
            
            %now check that the input data has been entered
            %isValidModel checks the InputHandles defined in ModelUI
            if ~isValidModel(mobj, metaclass(obj).Name)  
                warndlg('Use Setup to define model input parameters');
                return;
            end
            muicat = mobj.Cases;
            %assign the run parameters to the model instance
            %may need to be after input data selection to capture caserecs
            setRunParam(obj,mobj); 
%--------------------------------------------------------------------------
% Model code
%--------------------------------------------------------------------------
            [results,xy,bhw,Wmx] = breach_model(obj,mobj);                       
%--------------------------------------------------------------------------
% Assign model output to a dstable using the defined dsproperties meta-data
%--------------------------------------------------------------------------                   
            %each variable should be an array in the 'results' cell array
            %if model returns single variable as array of doubles, use {results}
            dst = dstable(results{:},'DSproperties',dsp);
            dst.Dimensions.X = xy{:,1};     %grid x-coordinate
            obj.WidthVals.bhw  = bhw;   %half width at high water                    
            obj.WidthVals.Wmx  = Wmx;   %maximum width 
%--------------------------------------------------------------------------
% Save results
%--------------------------------------------------------------------------                        
            %assign metadata about model
            dst.Source = metaclass(obj).Name;
            dst.MetaData = sprintf('Breach regime section for %d breaches',mobj.Inputs.mrSiteData.nBreaches);
            %save results
            setDataSetRecord(obj,muicat,dst,'model');
            getdialog('Run complete');
        end
    end
%%
    methods
        function tabPlot(obj,src,mobj) %abstract class for muiDataSet
            %generate plot for display on Q-Plot tab
            %data is retrieved by GUIinterface.getTabData    
            sV = mobj.Inputs.mrSiteData;
            iV = mobj.Inputs.mrBreachData;
            tabcb  = @(src,evdat)tabPlot(obj,src,mobj);
            ax = tabfigureplot(obj,src,tabcb,false);   
            breachModelPlot(obj,ax,sV,iV);          
        end
    end 
%%    
    methods (Access = private)
        function [zregime,yregime,bhw,Wmx] = breach_model(obj,mobj)
            %calculate the breach regime section
            site = mobj.Inputs.mrSiteData;        
            hydr = mobj.Inputs.mrBreachData;
            hyps = mobj.Inputs.mrHypsometry;
            %model parameters          
            ar  = 0.052;                %scale of aspect ratio function
            nr  = 0.667;                %shape of aspect ratio function
            %Site variables
            z0  = site.z0level;           %lowest inerodile site level (mOD)
            nob = site.nBreaches;         %number of breaches
            d50 = site.d50SedSize;        %particle size, m
            taucr = site.EroThreshold;    %critical erosion threshold, Pa
            rhow  = mobj.Constants.WaterDensity;    
            % Variables for forcing conditions
            tp  = hydr.TidalPeriod*3600;  %tidal period (secs)
            zhw = hydr.zHWlevel;          %HW level (mOD)
            zlw = hydr.zLWlevel;          %LW level (mOD) 
            wcflg = hydr.wcflg;           %flag; currents only=0, wave+current=1
            Uwd = hydr.WindSpeed;          %wind speed, ms^-1
            zw  = hydr.WindLevel;         %wind speed elevation, m above ground
            Fch = hydr.FetchLength;       %available fetch length, m
            df  = hydr.FetchDepth;        %average water depth over fetch, m
            
            %check if hypsometry exists
            if isempty(hyps.FitHypLevels)
                    hyps = selectHypsometry(hyps,mobj);
            end
            %get selected hypsometry
            if hyps.HypSelection<1
                zs = hyps.ObsHypLevels;
                ss = hyps.ObsHypAreas;
                zsite = zs(zs<=zhw);
                ssite = ss(zs<=zhw);
                if min(zsite)>zlw
                    %pad the array to LW so that interpolation works
                    zadd  = (zlw:0.2:min(zsite)-0.2)';
                    zsite = [zadd;zsite];
                    ssite = [zeros(size(zadd));ssite];
                end
            else
                zsite = hyps.FitHypLevels;
                ssite = hyps.FitHypAreas;
            end
                        
            %derived parameters
            omega= 2*pi/tp;      %angular tidal frequency
            amp  = (zhw-zlw)/2;  %tidal amplitude
            mtl  = zlw+amp;      %mean tide level
            %
            %--------------------------------------------------------------
            % Calculate the width required assuming a fixed invert and 
            % rectangular section: W = S*v/(Ucr*h)
            %--------------------------------------------------------------
            %
            tint = 10*60; 
            tz   = 0:tint:tp/2;                   %time step interval, secs
            zact = mtl+amp*cos(omega*tz+pi);      %tidal elevation
            sact = interp1(zsite,ssite,zact,'spline','extrap');
            sact = sact/nob; %assume plan area divided equally across no. of breaches, nob
            vt   = -amp*omega*sin(omega.*tz+pi);  %vertical rate of change of water surface
            ht   = (zact-z0).*(zact>z0);          %depth in site, set to zero if below z0 
            [Hs,Tp,~] = tma_spectrum(Uwd,zw,Fch,df,ht);
            ucr = ucrit(ht,d50,rhow,taucr,Hs,Tp,wcflg); %threshold velocity
            [Wb,~] = obj.getWbHb(ht,ucr,ar,nr,sact,vt); 
            Wmx  = max(Wb);
            %
            %--------------------------------------------------------------
            % Calculate regime width and crossectional profile
            %--------------------------------------------------------------
            %
            ht0 = (zact-zlw);
            [Hs0,Tp0,~] = tma_spectrum(Uwd,zw,Fch,df,ht0);
            ucr0 = ucrit(ht0,d50,rhow,taucr,Hs0,Tp0,wcflg);
            [Wb,Hb] = obj.getWbHb(ht0,ucr0,ar,nr,sact,vt);
            dh  = abs(Hb-ht0);
            %
            count = 0;
            %interative loop to find regime depth and width at each tidal interval
            while any(dh>0.00005) && count<100
                ht1 = Hb.*(Hb>=ht0);  %if Hb>ht0 ht0=Hb
                ht1 = ht1 + 0.5*(Hb+ht0).*(Hb<ht0); %otherwise ht0=(Hb+ht0)/2
                zoi = zact-ht1; 
                ht0 = ht1.*(zact>zoi); %update ht0
                [Hs0,Tp0,~] = tma_spectrum(Uwd,zw,Fch,df,ht0);
                ucr0 = ucrit(ht0,d50,rhow,taucr,Hs0,Tp0,wcflg);
                [Wb,Hb] = obj.getWbHb(ht0,ucr0,ar,nr,sact,vt);
                dh  = abs(Hb-ht0);
                count = count +1;
            end
%--------------------------------------------------------------------------
%Calculate the bounding profile for the regime width at all tidal 
%elevations.  First define the channel at maximum regime width and extends 
%this form to high water.  Then the depths for the widths that are less 
%than the maximum regime width are checked to see if the parabolic
%form is deeper and if so these values are used.  The routine uses half 
%widths in the Cao & Knight equations and defines the coefficient mu, 
%using the regime width, mu = 6.ar(Wb)^(nr-1).  Initially the value at the 
%maximum regime width is adopted but widths below this value mu is varied 
%to reflect the regime conditions at lower water levels
%--------------------------------------------------------------------------
            Wbmx  = max(Wb);          %maximum regime width
            itx   = Wb==Wbmx;   %index of maximium width
            mu    = 6*ar*Wbmx^(nr-1); %value of mu at maximum regime width
            ztx   = zact(itx);        %elevation of maximum regime width
            dz    = zhw-ztx;          %depth of maximum regime width below hw
            bhw   = Wbmx/2*sqrt(1+4*dz/mu/Wbmx); %half width at high water
            yint  = 1;                %interval for calculating profile on y-axis, m
            y     = 0:yint:bhw;       %initialise y co-ordinate
            dep   = mu*Wbmx/4*(1-(2*y/Wbmx).^2);%centre-line depths for maximum width
            zest  = ztx-dep;
            % now repeat calculations for all elevations at each interval across
            % profile
            mu    = 6*ar*Wb.^(nr-1);  %mu for regime width at all elevations
            zbed = zeros(size(y));
            ind = Wb>0;
            for j=1:length(y)
                dep(ind)   = mu(ind).*Wb(ind)/4.*(1-(2*y(j)./Wb(ind)).^2);
                zinv  = zact(ind)-dep(ind);
                if y(j)<Wbmx/2
                    zbed(j)= min([zest(j) min(zinv)]);
                else
                    zbed(j) = zest(j);
                end
            end
            maxy = max(y);
            y(1) = y(1)+0.1; %offset to avoid duplicates at mid-point
            yregime = {maxy+[fliplr(-y) y]};
            zregime = {[fliplr(zbed) zbed]}; %cell array of variables
        end
%%        
        function [Wb,Hb] = getWbHb(~,ht0,ucr,ar,nr,sact,vt)               
            %optimum width for depth ht0
            Wb = zeros(size(ucr));
            ind = ucr>0;
            Wb(ind) = sact(ind).*vt(ind)./ucr(ind)./ht0(ind);
            Hb  = ar*Wb.^nr; 
        end 
%%
        function breachModelPlot(obj,ax,sV,iV)
            %plot sections as tab plot or stand-alone figure
            dst = obj.Data.Dataset;
            z = dst.zCoords;%z co-ordinate data
            x = dst.Dimensions.X;
            p = obj.WidthVals;

            zhw = iV.zHWlevel;          %HW level (mOD)
            zlw = iV.zLWlevel;          %LW level (mOD)
            z0  = sV.z0level;           %lowest inerodile site level (mOD)
            
            plot( x,z,...
             '-r', 'DisplayName', 'Regime profile',...
             'XDataSource', 'yreg', 'YDataSource', 'xreg','LineWidth',1.5);
            xlabel('Distance (m)'); ylabel('Elevation (mODN)');
            hold on
            if ~isempty(p.bhw)
                hwline = [zhw zhw]; lwline = [zlw zlw]; zsline = [z0 z0];
                yline = [0 p.bhw*2];
                yrect = [p.bhw-p.Wmx/2 p.bhw-p.Wmx/2 p.bhw+p.Wmx/2 p.bhw+p.Wmx/2]; 
                zrect = [zhw z0 z0 zhw];
                plot(yline,hwline,'--b','LineWidth',1,'DisplayName','High water');
                plot(yline,lwline,'--b','LineWidth',1,'DisplayName','Low water');
                plot(yline,zsline,'-.g','LineWidth',1,'DisplayName','Breach invert');
                plot(yrect,zrect,':m','LineWidth',1,'DisplayName','Minimum box section');
            end
            hold off
            legend('show','Location','southwest')
            title(dst.Description)
            ax.Color = [0.96,0.96,0.96];  %needs to be set after plot            
        end
%%
        function dsp = modelDSproperties(~) 
            %define a dsproperties struct and add the model metadata
            dsp = struct('Variables',[],'Row',[],'Dimensions',[]); 
            %define each variable to be included in the data table and any
            %information about the dimensions. dstable Row and Dimensions can
            %accept most data types but the values in each vector must be unique
            
            %struct entries are cell arrays and can be column or row vectors
            dsp.Variables = struct(...                       % <<Edit metadata to suit model
                'Name',{'zCoords'},...
                'Description',{'Elevation'},...
                'Unit',{'mOD'},...
                'Label',{'Elevation (mOD)'},...
                'QCflag',{'model'}); 
            dsp.Row = struct(...
                'Name',{''},...
                'Description',{''},...
                'Unit',{''},...
                'Label',{''},...
                'Format',{''});        
            dsp.Dimensions = struct(...    
                'Name',{'X'},...
                'Description',{'Width'},...
                'Unit',{'m'},...
                'Label',{'Width (m)'},...
                'Format',{'-'});  
        end
    end           
end