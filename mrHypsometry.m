classdef mrHypsometry < muiPropertyUI 
    % class for measured and estimated site Hypsometry
%
%-------class help---------------------------------------------------------
% NAME
%   mrHypsometry.m
% PURPOSE
%   Class for measured and estimated site Hypsometry
% USAGE
%   obj = mrHypsometry()
% SEE ALSO
%   inherits muiPropertyUI
%
% Author: Ian Townend
% CoastalSEA (c) Jan 2021
%--------------------------------------------------------------------------
%
    properties (Hidden)
        %abstract properties in PropertyInterface for tab display
        PropertyLabels = {'Measured hypsometry file'}        
        TabDisplay   %structure defines how the property table is displayed
        %additional properites that are NOT included in the input UI
        ObsHypLevels                %array of observed site levels (mOD)
        ObsHypAreas                 %array of observed plan areas (m2)
        HypSelection = 1            %select between Fit=1 and Obs=0        
    end
    
    properties (Transient)
        HypFig                      %figure handle for hypsometry fitting 
        HypAx                       %handle for figure axes 
        rstCoefficient              %coefficient rst used in fitted hypsometry
        cstCoefficient              %coefficient cst used in fitted hypsometry
        FitHypLevels                %array of fitted site levels (mOD)
        FitHypAreas                 %array of fitted plan areas (m2)        
    end
    
    properties
        HypsometryFile              %file for measured hypsometry, format:
                                    %2 header lines, 2 columns for: 
                                    %elevation (mOD) and
                                    %plan area (m2)        
    end
%%
    methods 
        function obj = mrHypsometry(mobj)             
            %class constructor
            %TabDisplay values defined in UI function setTabProperties used to assign
            %the tabname and position on tab for the data to be displayed
            obj = setTabProps(obj,mobj);  %muiPropertyUI function
        end
    end
%%   
    methods (Static)               
        function loadHypsometry(mobj)
            %import observed hypsometry data from file
            classname = 'mrHypsometry';              
            obj = getClassObj(mobj,'Inputs',classname);
            if isempty(obj)
                obj = mrBHypsometry(mobj);             
            end   
            
            [fname,path,~] = getfiles('FileType','*.txt');
            filename = [path fname];
            obj.HypsometryFile = filename;
            dataSpec = '%f %f'; 
            nhead = 2;     %number of header lines
            [data,~] = readinputfile(filename,nhead,dataSpec);
            
            obj.ObsHypLevels = data{1};
            obj.ObsHypAreas  = data{2};
            setClassObj(mobj,'Inputs',classname,obj);
        end 
%%
        function setHypsometry(mobj)
            %use Input data to set up theoretical hypsometry and plot
            %against Observed data if loaded
            classname = 'mrHypsometry';              
            if isfield(mobj.Inputs,classname) && ...
                            isa(mobj.Inputs.(classname),classname)
                obj = mobj.Inputs.(classname);  
            else
                obj = mrHypsometry(mobj);                  
            end
            
            obj = selectHypsometry(obj,mobj);
            if isempty(obj.cstCoefficient) && obj.HypSelection==1  %fitted model
                warndlg('No root found for cst in starhlerHypsometry')
                return;
            end
            h_pnl = findobj(obj.HypFig,'Tag','ButtonPanel');
            delete(h_pnl);
            delete(obj.HypFig);
            mobj.Inputs.(classname) = obj;
        end
%%
        function tabHypsometry(mobj,src,~)
            %generate plot for display on Hypsometry tab

            if strcmp(src.Tag,'FigButton')
                obj = getClassObj(mobj,'Inputs','mrHypsometry'); %hypsometry instance
                hfig = figure('Tag','PlotFig');
                ax = axes('Parent',hfig,'Tag','PlotFig','Units','normalized');
                plotHypsometry(obj,ax);
            else
                ht = findobj(src,'Type','axes');
                delete(ht);
                ax = axes('Parent',src,'Tag','Q-Plot');
                %check that hypsommetry has been generated
                obj = getClassObj(mobj,'Inputs','mrHypsometry'); %hypsometry instance
                isvalid = isValidModel(mobj,'mrBreachModel');    %input data
                if ~isvalid && isempty(obj)
                    warndlg('No input or observed data available')
                    return;
                elseif isempty(obj)
                    obj = mrHypsometry(mobj);
                end
                %
                if isvalid && isempty(obj.FitHypLevels)
                    obj = strahlerHypsometry(obj,mobj);
                    if isempty(obj.cstCoefficient)
                        warndlg('No root found for cst coefficient')
                        return;
                    end
                    obj = fittedData(obj,mobj);
                end
                %plot results
                plotHypsometry(obj,ax);
                txtstr = 'The thicker line is the hypsometry currrently selected for the model';                
                hx = findobj(src,'Tag','IStext');
                if isempty(hx)
                    uicontrol('Parent',src,...
                        'Style','text','String',txtstr,...
                        'HorizontalAlignment','left',...
                        'Units','normalized','Position',[0.15,0.86,0.6,0.04],...
                        'Tag','IStext');
                end
                
                hb = findobj(src,'Tag','FigButton');
                if isempty(hb)
                    %button to create plot as stand-alone figure
                    uicontrol('Parent',src,'Style','pushbutton',...
                        'String','>Figure','Tag','FigButton',...
                        'TooltipString','Create plot as stand alone figure',...
                        'Units','normalized','Position',[0.88 0.95 0.10 0.044],...
                        'Callback',@(src,evdat)mrHypsometry.tabHypsometry(mobj,src,evdat));
                else
                    hb.Callback = @(src,evdat)tabPlot(obj,src);
                end
            end
        end
    end
%%
    methods
        function obj = selectHypsometry(obj,mobj)
            %setup figure and allow user to adjust fit paramaters return
            %a selected hypsometry (theoretical or observed)          
            iV = getClassObj(mobj,'Inputs','mrBreachData','Hydraulic data not defined');
            sV = getClassObj(mobj,'Inputs','mrSiteData','Site data not defined');
            if isempty(iV) || isempty(sV)
                return;
            end
            %initialise hypsometry plot
            obj.HypFig = figure('Name','Hypsometry Plot','Tag','PlotFig',...
                'Position',[100,100,560,580],'Resize','off',...
                'CloseRequestFcn',@obj.close_figure);
            obj.HypAx = axes('Parent',obj.HypFig,...
                'Position',[0.1,0.16,0.85,0.76]);
            %initialise properties
            obj = strahlerHypsometry(obj,mobj);
            if isempty(obj.cstCoefficient)
                warndlg('No root found for cst coefficient')
                delete(obj.HypFig)
                return;
            end
            %get theoretical fit for site and plot
            obj = fittedData(obj,mobj);
            plotHypsometry(obj,obj.HypAx);
            %add sliders to alter Rst and Cst and replot theoretical curve
            Rpos = [0.05,0.02,0.4,0.03];            
            Slider(obj,'rstCoefficient',Rpos,mobj);
            Cpos = [0.55,0.02,0.4,0.03];
            Slider(obj,'cstCoefficient',Cpos,mobj);
            promptxt = 'Use Fit or Obs?';
            h_pnl = acceptpanel(obj.HypFig,promptxt,{'Fit','Obs'},[0.43,0.927,0.2,0.07]);  
            waitfor(h_pnl,'Tag');
            %fitted model is the default if figure closed with Exit button or there is no data
            obj.HypSelection = 1;         %use fitted model 
            if strcmp(h_pnl.Tag,'Obs') && isempty(obj.ObsHypLevels)
                warndlg('No observed data. Using model values')
            elseif strcmp(h_pnl.Tag,'Obs')
                obj.HypSelection = 0;     %use observations 
            end
        end
        
 %% ---Main calculation functions---->
        function obj = fittedData(obj,mobj)
            %get theoretical data set based on Strahler hypsometry    
            iV  = mobj.Inputs.mrBreachData;  %input data
            sV  = mobj.Inputs.mrSiteData;    %site data
            rst = obj.rstCoefficient;  %rst fit coefficient
            cst = obj.cstCoefficient;  %cst fit coefficient 
            %
            sst  = @(z) z.^(1/cst)./((1-rst)*z.^(1/cst)+rst);
            %
            zsite = sV.z0level:0.1:iV.zHWlevel;     %use site range
            %non-dimensional elevation
            zst  = (zsite-sV.z0level)/(iV.zHWlevel-sV.z0level);
            %plan area 
            ssite = (sst(zst)*(sV.HWArea-sV.z0Area)+sV.z0Area);
            %assign to object
            obj.FitHypLevels = zsite;
            obj.FitHypAreas  = ssite;
        end
%%        
        function obj = strahlerHypsometry(obj,mobj)
            %use the integral to find an estimate of cst given rst and vnx
            iV  = mobj.Inputs.mrBreachData;  %input data
            sV  = mobj.Inputs.mrSiteData;    %site data
            vnx = sV.TidalPrism/(sV.HWArea-sV.z0Area);  %dimensionless volume
            vnx = vnx/(iV.zHWlevel-sV.z0level);
            rst = 0.05+8*exp(-12*vnx);  %empirical estimate of coefficient rst
            st = @(z,c) z.^(1/c)./((1-rst)*z.^(1/c)+rst);  %Eq.(7)for s'
            Ist = @(c) integral(@(z)st(z,c),0,1); %Eq(9) for v'
            fun = @(c) vnx-Ist(c);
            [cst,~,exitflag] = fzero(fun,0.5);
            if exitflag<0  %root not found
                cst = [];
            end
            %
            obj.rstCoefficient = rst;
            obj.cstCoefficient = cst;
        end
        
 %% ----Graphical controls ----->    
        function plotHypsometry(obj,ax)
            %plot the theoretical and measured site hypsometry
            if obj.HypSelection<1
                lwidth = [0.6,1.2];
            else
                lwidth = [1.2,0.6];
            end
            plot(ax,obj.FitHypAreas,obj.FitHypLevels,'b',...
                        'LineWidth',lwidth(1),'DisplayName','Empirical');
                    
            if ~isempty(obj.ObsHypAreas)
                hold on
                plot(ax,obj.ObsHypAreas,obj.ObsHypLevels,'r',...
                        'LineWidth',lwidth(2),'DisplayName','Observed');
                hold off
            end
            xlabel('Plan area (m^2)')
            ylabel('Elevation (mOD)')
            title('Hypsometry profiles')
            legend('show','Location','southeast')
        end
%%
        function hs = Slider(obj,sVal,sPos,mobj)
            %default slider definition
            if obj.(sVal)>1
                maxVal = obj.(sVal)*2;
            else
                maxVal = 1;
            end
            sValTxt = sprintf('%s=%g',sVal,obj.(sVal));
            hs = uicontrol('Parent',obj.HypFig,...
                'Style','slider',...
                'Max',maxVal,...
                'Min',0,...
                'Value',obj.(sVal),...
                'Units','normalized',...
                'Position',sPos,...
                'SliderStep',[0.003,0.005],...
                'Callback',@(src,evt)sliderCallback(obj,src,evt,mobj),...
                'Tag',sVal);
            sPos(2) = sPos(2)+0.02;
            uicontrol('Parent',obj.HypFig,...
                'Style','text',...
                'String',sValTxt,...
                'Units','normalized',...
                'Position',sPos,...
                'Tag',sVal);
            endPos = sPos(1)+sPos(3);
            sPos(3) = 0.05; sPos(4) = 0.027;
            uicontrol('Parent',obj.HypFig,...
                    'Style','text','String',0,...                    
                    'HorizontalAlignment', 'left',...
                    'Units','normalized', 'Position', sPos,...
                    'Tag','IStext'); 
            sPos(1) = endPos-0.005;
            uicontrol('Parent',obj.HypFig,...
                    'Style','text','String',num2str(maxVal),...                    
                    'HorizontalAlignment', 'left',...
                    'Units','normalized', 'Position', sPos,...
                    'Tag','IStext'); 
        end
%%
        function sliderCallback(obj,src,~,mobj)
            %reset theoretical line and update plot
            switch src.Tag
                case 'rstCoefficient'
                    obj.rstCoefficient = src.Value;
                case 'cstCoefficient'
                    obj.cstCoefficient = src.Value;
            end
            %
            obj = fittedData(obj,mobj);
%             mobj.Inputs.myHypsometry = obj;
            %
            updatePlot(obj);
            updateSliderText(obj,src)
        end        
%%
        function updatePlot(obj)
            %update teoretical plot line based on callback changes
            zsite = obj.FitHypLevels;
            ssite = obj.FitHypAreas;
            hline = findobj(obj.HypAx,'DisplayName','Empirical');
            delete(hline)
            hold on
            plot(ssite,zsite,'b','LineWidth',1,'DisplayName','Empirical');
            hold off
        end
%%
        function updateSliderText(obj,src)
            %adjust slider text
            sValTxt = sprintf('%s=%g',src.Tag,src.Value);
            htext = findobj(obj.HypFig,'Tag',src.Tag);
            htext = findobj(htext,'Style','text');
            htext.String = sValTxt;
        end
%%
        function close_figure(obj,~,~)
            %close figure from Close button or figure X
            if isvalid(obj)
                h_pnl = findobj(obj.HypFig,'Tag','ButtonPanel'); 
                if isempty(h_pnl)
                    delete(gcf);                       
                else
                     h_pnl.Tag = 'ExitFig';
                end
            else
                hcf = findobj('tag','PlotFig');
                if ~isempty(hcf)
                    delete(hcf);
                    clear hcf
                end     
            end
        end
    end
end
    
    
    
    
    
    
    

