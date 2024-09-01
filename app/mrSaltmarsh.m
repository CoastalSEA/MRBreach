classdef mrSaltmarsh < muiPropertyUI        
%
%-------class help------------------------------------------------------===
% NAME
%   Saltmarsh.m
% PURPOSE
%   Class to define saltmarsh and handle the influence on morphology
% USAGE
%   obj = Saltmarsh.setInput(mobj); %mobj is a handle to Main UI
% SEE ALSO
%   inherits muiPropertyUI
%
% Author: Ian Townend
% CoastalSEA (c) Jan 2021
%--------------------------------------------------------------------------
%      
    properties (Hidden)
        %abstract properties in muiPropertyUI to define input parameters
        PropertyLabels = {'Number of saltmarsh species',...
                          'Minimum depth (m)','Maximum depth (m)',...
                          'Maximum biomass (kg/m2)',...
                          'Species productivity (m2/kg/yr)',...
                          'Settling cofficient, alpha (m/s)',...
                          'Settling exponent, beta (-)'};
        %abstract properties in muiPropertyUI for tab display
        TabDisplay   %structure defines how the property table is displayed 
    end
    
    properties
        NumSpecies          %number of saltmarsh species
        MinSpDepth          %minimum depth for each species (m)
        MaxSpDepth          %maximum depth for each species (m)
        MaxBiomass          %maximum biomass for each species (kg/m2)
        SpeciesProduct      %species productivity (m2/kg/yr)
        SettlingAlpha       %coefficient for biomass enhanced settling rate (m/s)
        SettlingBeta        %exponent for biomass enhanced settling offset (-)
    end    
    
    properties (Transient)
        MarshDepthConc      %lookup table of concentrations over marsh [depth,conc,submergence]
        ModelMovie          %most recent run of saltmarsh animation function
    end

%%   
    methods (Access=protected)
        function obj = mrSaltmarsh(mobj)  
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
            classname = 'mrSaltmarsh'; 
            obj = getClassObj(mobj,'Inputs',classname);
            if isempty(obj)
                obj = mrSaltmarsh(mobj);             
            end
            
            %use muiPropertyUI function to generate UI
            if nargin<2 || editflag
                %add nrec to limit length of props UI (default=12)
                obj = editProperties(obj);  
                %add any additional manipulation of the input here
            end
            setClassObj(mobj,'Inputs',classname,obj);
        end    

%% ------------------------------------------------------------------------
% Static functions for plots and animations to display aspects of model setup
%--------------------------------------------------------------------------
        function EqDepthBiomassPlot(mobj)
            %examine influence of biomass production rates on equilibirum depth
            %produces three graphs and displays the resultant eq.depth
            %get input parameters             
            [obj,wlvobj,cn] = mrSaltmarsh.getInputData(mobj);
            if isempty(obj) || isempty(wlvobj), return; end
            %--------------------------------------------------------------
            % Store original values of kbm so that they can be restored
            kbm0 = obj.SpeciesProduct;     %species productivity (m2/kg/yr)
            %-------------------------------------------------------------- 
            [sm,ct] = initialiseSaltmarshModel(obj,wlvobj,cn,mobj);
            if isempty(ct), return; end
            
            %--------------------------------------------------------------
            % Calculate variation with slr
            %--------------------------------------------------------------
            nint = 100;         %number of intervals
            minslr = 0.0001;    %starting value of slr
            deq = zeros(nint,1); slr = deq; biom = deq;
            for jd = 1:nint %x axis
                slr(jd) = minslr*jd; %rate of slr in m/yr
                [dep,~] = interpdepthload(obj,cn,sm.aws,sm.qm1,slr(jd)/cn.y2s);%uses (sm,cn,aws,qm0,dslr)
                deq(jd) = dep;
                if dep>0                
                    dd  = [dep dep.^2 1];
                    bm = sm.Bc*dd';
                    biom(jd) = sum(bm.*(bm>0));
                else
                    biom(jd)=0;
                end
            end
            %--------------------------------------------------------------
            % Restore original values of kbm
            obj.SpeciesProduct = kbm0;
            %--------------------------------------------------------------            
            % Plot results
            Dslr = sm.dslr*cn.y2s*1000;     %units of mm/year
            Qm1 = sm.qm1*cn.y2s;            %units of yr^-1     
            ptxt = struct('kbm',sm.userkbm,'dp0',sm.dp0,'dp1',sm.dp1,...
                        'Qm0',sm.Qm0,'Qm1',Qm1,'Dslr',Dslr,'bm1',sm.bm1,...
                        'minslr',minslr,'maxslr',minslr*nint);
            bioInfluencePlot(obj,cn,slr,deq,biom,ptxt);
            % Advise state of marsh if elements defined
            marshElementCheck(obj,mobj)
        end
%%
        function BiomassDistributionPlot(mobj)
            %plot the distribution of each species on the bare flat profile
            [obj,wl,~] = mrSaltmarsh.getInputData(mobj);
            if isempty(obj) || isempty(wl), return; end

            width = inputdlg('MTL to HW width:','Saltmarsh width',1,{'500'});
            if isempty(width), return; end
            width = str2double(width);  
            a = wl.TidalAmp;
            [y,z] = getFlatProfile(obj,a,width,100); %nint=100
            Bc = morris_biocoeffs(obj);
            
            dmx = max(obj.MaxSpDepth);
            depth = 0:0.01:dmx;
            biomass = zeros(obj.NumSpecies,length(depth));
            for i=1:length(depth)
                    bm = Bc*[depth(i);depth(i)^2;1];
                    biomass(:,i) = bm.*(bm>0);
            end
            bioDistributionPlot(obj,y,z,biomass,depth,a,[]);
        end
%%
%         function MarshFlatAnimation(mobj)
%             %animation of the development of marsh from initial bare flat
%             [obj,wlvobj,eleobj,cn] = Saltmarsh.getInputData(mobj);
%             if isempty(obj) || isempty(wlvobj), return; end
%             %--------------------------------------------------------------
%             % Store original values of kbm so that they can be restored
%             kbm0 = obj.SpeciesProduct;     %species productivity (m2/kg/yr)
%             %-------------------------------------------------------------- 
%             [sm,ct] = initialiseSaltmarshModel(obj,wlvobj,eleobj,cn,mobj);
%             if isempty(ct), return; end
%             
%             %prompt for run parameters
%             answer = inputdlg({'MTL to HWL width:','No of years simulation',...
%                                  'Start year','Include decay, 1=true'},...
%                                  'Saltmarsh width',1,{'500','100','1900','0'});
%             if isempty(answer), return; end
%             width = str2double(answer{1});    
%             nyears = str2double(answer{2});
%             styear = str2double(answer{3})*cn.y2s;
%             isdecay = logical(str2double(answer{4}));
%             
%             %get initial mud flat profile
%             a = wlvobj.TidalAmp;
%             [y,z0] = getFlatProfile(obj,a,width,100); %nint=100
%             ymx = interp1(z0,y,(a-sm.dmx));
%             
%             %initialise run time parameters and water levels
%             mtime = 0:1:nyears; 
%             nint = length(mtime);
%             mtime = mtime*cn.y2s;
%             dt = 1*cn.y2s;
%             [zHW,msl] = newWaterLevels(wlvobj,mtime,styear); 
%             
%             %compute saltmarsh elevations
%             z = repmat(z0,nint,1);            
%             hw = waitbar(0,'Running model');
%             for i=2:nint  
%                 idep = find(z(i-1,:)<(zHW(i)-sm.dmx),1,'last');
%                 depth = zHW(i)-z(i-1,:);
%                 cz = interp1(ct.Depth,ct.Concentration,depth);
%                 %assume lower flat keeps pace with change in msl
%                 z(i,1:idep) = z(i-1,1:idep)+(msl(i)-msl(i-1)); %change tidalflat
%                 for j=idep+1:length(z)                    
%                     bm = sm.Bc*[depth(j);depth(j)^2;1];
%                     sumKB = sum(sm.kbm.*(bm.*(bm>0)));  
%                     wsb = bioenhancedsettling(obj,depth(j),sm.aws);
%                     if isdecay
%                         %apply a linear decay in concentration across 
%                         %the upperflat width (MTL to HWL)
%                         yi = y(i)-ymx;
%                         cz(j) = cz(j)*((width-yi)/(width-ymx));
%                     end
%                     %see eqn (4) and (9) inTownend et al, COE 2016 paper
%                     % ie qm*D = wsb*1/T*integral(c*dt) == wsb*cz
%                     dz = (wsb*cz(j)+sumKB*depth(j))*dt; %Krone's change in depth
%                     dz(isnan(dz)) = 0;
%                     z(i,j) = z(i-1,j)+dz;               %change to marsh                      
%                 end
%                 waitbar(i/nint)
%             end
%             close(hw)
%             %--------------------------------------------------------------
%             % Restore original values of kbm
%             obj.SpeciesProduct = kbm0;
%             %--------------------------------------------------------------
%             time = (styear+mtime)/cn.y2s;            
%             marshAnimationFigure(obj,y,z0,z,time,zHW,sm.dmx)
%         end
    end
%% ------------------------------------------------------------------------
% Private functions called by static functions BioProduction and EqDepth
%-------------------------------------------------------------------------- 
    methods (Access=private) 
        function [sm,ct] = initialiseSaltmarshModel(obj,wlvobj,cn,mobj)
            %Set up inputs needed by MarshFlatAnimation and EqDepthBiomass             
            newWaterLevels(wlvobj,0,0);                
            sm.dslr = wlvobj.SLRrate/cn.y2s;  %rate of sea level change (m/s)
            
            %intitialise transient properties            
%                 Element.initialiseElements(mobj);
%                 Element.setEqConcentration(mobj);
%                 [sm.aws,c0] = getMarshVerticalExchange(obj,eleobj);    
            
            %marsh concentration options
            mco.tsn = 14.77;          %duration of spring-neap cycle (days) 
            mco.delt = 10;            %time step (secs)  *may be sensitive
            mco.dmin = 0.05;          %minimum depth used in calculation           
            ct = concovermarsh(obj,wlvobj,c0,sm.aws,mco);         
            if all(ct.Concentration==0)
                ct = [];
                warndlg('Zero concentrations. Check Saltmarsh and Tidal Constituents are defined')
                return;
            end
            obj.MarshDepthConc = ct;
             %--------------------------------------------------------------
            % Get user defined value of kbm
            %--------------------------------------------------------------
            kbm0 = obj.SpeciesProduct;     %species productivity (m2/kg/yr)
            prompt = {'Enter biomass production rate (m^2kg^-1yr^-1)'};
            dlg_title = 'Input for biomass production rate';
            def = {num2str(kbm0)};
            dlg_ans = inputdlg(prompt,dlg_title,1,def);
            if isempty(dlg_ans), ct = []; return; end  
            obj.SpeciesProduct = str2num(dlg_ans{1}); %#ok<ST2NM>
            sm.userkbm = obj.SpeciesProduct;         %values in years
            %
            sm.Qm0 = 0.00018;       %estimate of sediment load used by Morris,2006
            if mean(sm.userkbm)< 1.0e-10*cn.y2s
                sm.Qm0 = 0.0018;    %adjustment needed if kbm very low, Morris, 2007
            end
            qm0 = sm.Qm0/cn.y2s;    %initial value of qm (s^-1)
            dp0 = morris_eqdepth(obj,cn,qm0,sm.dslr);
            if dp0<=0
                dmn = obj.MinSpDepth;          %minimum depth for each species (m)
                dmx = obj.MaxSpDepth;          %maximum depth for each species (m)
                dp0 = mean((dmn+dmx)/2);  
            end
            ct = obj.MarshDepthConc; %concentration over marsh as a function of depth
            cem = interp1q(ct.Depth,ct.Concentration,dp0);            
            wsm = bioenhancedsettling(obj,dp0,sm.aws);
            qm0 = wsm*cem/dp0;
            sm.dp0 = morris_eqdepth(obj,cn,qm0,sm.dslr);
            %--------------------------------------------------------------
            % Calculate depth, dp1, sediment loading, qm1, biomass
            % coefficients Bc, total biomass at equilibrium depth, bm1
            %--------------------------------------------------------------
            [sm.dp1,sm.qm1] = interpdepthload(obj,cn,sm.aws,qm0,sm.dslr);
            sm.Bc = morris_biocoeffs(obj);
            dd1 = [sm.dp1 sm.dp1.^2 1];
            bm0 = (sm.Bc*dd1');
            sm.bm1 = sum(bm0.*(bm0>0)); %total biomass at equilibrium depth (kg.m^-2)
            sm.dmx = max(obj.MaxSpDepth); 
        end
%%
        function [y,z] = getFlatProfile(~,a,width,nint)
            %bare flat profile based on Friedrichs tidal equilibrium form
            Ls = width/(pi/2);
            y = 0:width/nint:width;
            z = a*sin(y/Ls);
        end
%%
        function bioDistributionPlot(obj,y,z,biomass,depth,a,hfig)
            %plot of profile and biomass distribution for each species
            if isempty(hfig)
                hfig = figure('Name','Biomass Plot','Tag','PlotFig');
            end
            
            ax1_pos = [0.165,0.11,0.65,0.79]; % position of first axes
            ax1 = axes(hfig,'Position',ax1_pos,...
                      'XAxisLocation','bottom','YAxisLocation','left');  

            profilePlot(obj,y,z,a,ax1); %plot tidal flat profile and HW            
            ax1.YLim = [ax1.YLim(1),a+0.1];

            style = {'-','-.','--',':'};
            green = mcolor('green');
            ax2 = axes(hfig,'Position',ax1_pos,'XAxisLocation','top',...
                'YAxisLocation','right','Color','none');
            ax2.XDir = 'reverse';
            ax2.YLim = ax1.YLim;
            ax2.YTickLabel = string(a-ax1.YTick);
            zd = a-depth;
            
            line(biomass(1,:),zd,'Parent',ax2,'Color',green,...
                              'LineStyle','-','DisplayName','Species 1')
            hold on            
            for j=2:obj.NumSpecies
                spectxt = sprintf('Species %d',j);
                line(biomass(j,:),zd,'Parent',ax2,'Color',green,...
                              'LineStyle',style{j},'DisplayName',spectxt)          
            end
            hold off            
            xlabel('Biomass (kg/m^2)')
            ylabel('Depth')
            
            legend(ax2,'Location','east')
        end
%%
        function profilePlot(~,y,z,a,ax)
            %plot base tidal flat profile
            plot(ax,y,z,'Color','k','DisplayName','Tidal flat')
            hold on
            plot(ax,ax.XLim, a*[1 1],'Color','b','DisplayName','High water')
            hold off
            xlabel('Distance (m)')
            ylabel('Elevation (mOD)')
            legend(ax,'Location','southeast')
        end

%% 
    end
 %%
    methods (Static,Access=private)
        function [obj,wl,cn] = getInputData(mobj)
            %initialise saltmarsh, water levels and constants
            msgtxt = 'Saltmarsh parameters not defined';
            obj = getClassObj(mobj,'Inputs','mrSaltmarsh',msgtxt);
            msgtxt = 'Water level data not defined';
            wl = getClassObj(mobj,'Inputs','mrBreachData',msgtxt);
            cn = getConstantStruct(mobj.Constants);
        end
    end  
end