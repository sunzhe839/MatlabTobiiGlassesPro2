% Calibrate Head Tracking in Tobii for the Psychophsyics Booth
global vE
initialiseDirs
vE.avGUIHandles = [];
vE.fixation.Ele = -7.5;
vE.fixation.Az = 0;
instrreset;
% Initialisation
initialiseLEDs;
pause(2);
% Variables
locations = readtable('CalibrationLocations.txt');
noLocs = size(locations,1);
currRow = 1;
clicks = 0;
noReps = 5;
tobiiError = 0;


% Init calib parameters
calib.Pitch = 0;
calib.Roll = 0;
calib.X = 0;
calib.Z = 0;
calib.Y = 0;

%Get first response and new calibration parameters
% try
%     load(sprintf('%s','C:\Psychophysics\HeadCalibrations\',date,'_temp_Head_Calibration.mat'))
% catch

disp('Please put the glasses on a flat surface and press any key when ready')
KbStrokeWait;
LEDcontrol(vE.fixation.Az,vE.fixation.Ele,'on')
[~,~,currAngle,currAccRoll,currAccPitch] = getHeadwithPython(calib,10,0);
t = 1:length(currAngle.X);
calib.Pitch = mean(currAccPitch);
calib.Roll = mean(currAccRoll);
fitvars = polyfit(t,currAngle.Y,1);
calib.Y = fitvars(1); % botch way of canceling out the drift
disp('Drift calibrated.')

% save(sprintf('%s','C:\Psychophysics\HeadCalibrations\',date,'_temp_Head_Calibration.mat'),'calib')
% end

% Get participant name
partName = vE.thisSub(end-1:end);

% To avoid just getting one tobii cell need to presend a keep alive message
disp('Response calibration time, press any key when ready and click the mouse when sitting and looking at the centre light')
KbStrokeWait;
calibResponses = zeros(4,noReps,noLocs);
currCount = 1;
system('python stayingalive.py'); %Take about a second so may only need this at the begininng of most responses
for currRep = 1:noReps
    % Randomise the locations
    LocOrder = randperm(noLocs);
    for currLoc = 1:noLocs
        carryon = 1;
        while carryon == 1
            % Light centre light
            LEDcontrol('Location','on','white',vE.fixation.Az,vE.fixation.Ele);
            GetClicks();
            LEDcontrol('Location','off','white',vE.fixation.Az,vE.fixation.Ele);
            % Light up target light
            pause(0.1)
            LEDcontrol('Location','on','white',locations.Azimuth(LocOrder(currLoc)),...
                locations.Elevation(LocOrder(currLoc)));
            % Turn on guide lights            
            LEDcontrol('Location','on','green',vE.fixation.Az,vE.fixation.Ele);
            if locations.Elevation(LocOrder(currLoc)) ~= 0
                for trackLED = -7.5:7.5*sign(locations.Elevation(LocOrder(currLoc))):locations.Elevation(LocOrder(currLoc))
                    LEDcontrol('Location','on','green',0,trackLED)
                end
            elseif locations.Azimuth(LocOrder(currLoc)) ~= 0
                for trackLED = 0:7.5*sign(locations.Azimuth(LocOrder(currLoc))):locations.Azimuth(LocOrder(currLoc))
                    LEDcontrol('Location','on','green',trackLED,0)
                end
            end
            
            [responseFBAz,responseFBEle,~,~,~,tobiiError,leftClick,rightClick] = getHeadwithPython(calib,...
                'clicks',0);
            
            % Turn off guide lights
            LEDcontrol('Location','off','green',vE.fixation.Az,vE.fixation.Ele);
            if locations.Elevation(LocOrder(currLoc)) ~= 0
                for trackLED = -7.5:7.5*sign(locations.Elevation(LocOrder(currLoc))):locations.Elevation(LocOrder(currLoc))
                    LEDcontrol('Location','off','green',0,trackLED)
                end
            elseif locations.Azimuth(LocOrder(currLoc)) ~= 0
                for trackLED = 0:7.5*sign(locations.Azimuth(LocOrder(currLoc))):locations.Azimuth(LocOrder(currLoc))
                    LEDcontrol('Location','off','green',trackLED,0)
                end
            end
            
            fprintf('%s %s %s %s %s\n','Subject response location was at ',num2str(responseFBAz),...
                ' degrees in Azimuth and ',num2str(responseFBEle),' degrees in Elevation.')
            fprintf('%s %s %s %s %s\n','Target response location was at ',num2str(locations.Azimuth(LocOrder(currLoc))),...
                ' degrees in Azimuth and ',num2str(locations.Elevation(LocOrder(currLoc))),' degrees in Elevation. Error: ')
            disp(num2str(tobiiError))
            LEDcontrol('Location','allOff');
            calibResponses(:,currRep,LocOrder(currLoc)) = [locations.Azimuth(LocOrder(currLoc)),...
                responseFBAz,locations.Elevation(LocOrder(currLoc)),responseFBEle];
            save(sprintf('%s',vE.thisSubDir,'\',vE.sessionType,'\',num2str(vE.sessionNumber),'\',date,'calibResponses.mat'),'calibResponses')
            if tobiiError == 0 && rightClick == 0 %% add in msitake functionality
                carryon = 0;
            end
        end
    end
end

save(sprintf('%s',vE.thisSubDir,'\',vE.sessionType,'\',num2str(vE.sessionNumber),'\',date,'calibResponses.mat'),'calibResponses','calib','vE')
% save(sprintf('%s','C:\Psychophysics\HeadCalibrations\',date,'calibResponses.mat'),'calibResponses','calib','vE')

% analyseHeadCalib('C:\Users\King Admin\Desktop\Mark_elAziPlug\eleAziPlug\data\88_KP\intermittent\1\20-Feb-2018calibResponses.mat','KP')

LEDcontrol('Location','on','green',vE.fixation.Az,vE.fixation.Ele);
analyseHeadCalib(sprintf('%s',vE.thisSubDir,'\',vE.sessionType,'\',num2str(vE.sessionNumber),'\',date,'calibResponses.mat'),partName,vE)
LEDcontrol('Location','allOff')
