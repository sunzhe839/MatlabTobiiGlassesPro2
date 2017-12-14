% New get Head using python (because apparently Matlab UDP is shite
%% Function to get the head response angle in azimuth and elevation
function [responseFBAz,responseFBEle,currAngle,...
    currAccRoll,currAccPitch] = getHeadwithPython(calib,responseType,LocAz,LocEle)

% profile on

% Runs python code that grabs the livestream data (second argument is
% calibTime or 'clicks'
if isstring(responseType)==0
    responseType = num2str(responseType);
end
tic
disp('Recording')
rawtobiiData = python('livestream_data.py',responseType);
toc

% Sorting out the incoming data
tic
rawtobiiData = strsplit(rawtobiiData)';
tobiiData = {};
for i = 1:length(rawtobiiData)
    if i == 1
        tobiiData{i,1} = rawtobiiData{i,1}(4:end-4);
    else
        tobiiData{i,1} = rawtobiiData{i,1}(3:end-4);
    end
end

% Set up variables
currGyRow = 1; currAccRow = 1;
currAngle.X = 0; currAngle.Y = 0; currAngle.Z = 0;

% Pull Data from the JSON Cell array
for currRow = 1:length(tobiiData)
    if contains(tobiiData{currRow},'gy') %pulls out the GY JSON lines
        if tobiiData{currRow}(end)=='}'
            GyTs(currGyRow) = str2double(tobiiData{currRow}...which is in microseconds
                (7:strfind(tobiiData{currRow},',')-1)); %gets the Ts
            currGy = strsplit(tobiiData{currRow},','); %splits the Gy Data
            if length(currGy)==5
                Gy(currGyRow,1) = str2double(currGy{3}(strfind(currGy{3},'[')+1:end)); %x Gy
                Gy(currGyRow,2) = str2double(currGy{4}); %y Gy
                Gy(currGyRow,3) = str2double(currGy{5}(1:end-2)); %z Gy
                currGyRow = currGyRow + 1;
            end
        end
    elseif contains(tobiiData{currRow},'ac')
        if tobiiData{currRow}(end)=='}'
            AccTs(currAccRow) = str2double(tobiiData{currRow}...
                (7:strfind(tobiiData{currRow},',')-1)); %gets the Ts
            currAcc = strsplit(tobiiData{currRow},','); %splits the Acc Data
            %put a line in here to check the s
            if length(currAcc)==5 %to ignore any lost data
                Acc(currAccRow,1) = str2double(currAcc{3}(strfind(currAcc{3},'[')+1:end)); %x Acc
                Acc(currAccRow,2) = str2double(currAcc{4}); %y Acc
                Acc(currAccRow,3) = str2double(currAcc{5}(1:end-2)); %z Acc
                currAccRow = currAccRow + 1;
            end
        end
    end
end

% Get the sampling rates (should pick a value at some point to standardise
% it but currently just using the mode
GyHz = mode(diff(GyTs));
AccHz = mode(diff(AccTs));
dt = GyHz*1e-6; % get the sample rate in seconds for the integration

% Chuck in a low pass filter on Gy(:,2)


% Smoooooooothing
oldAcc = Acc;
oldGy = Gy;
for i = 1:size(oldAcc,2)
    Acc(:,i) = smooth(oldAcc(:,i),0.02,'moving'); %smoothing on Acc data is it is noisy
end
for i = 1:size(oldGy,2)
    Gy(:,i) = smooth(oldGy(:,i),0.02,'moving'); %smoothing on Acc data is it is noisy
end

% Resamples data as Acc and Gy have slightly differing sample rates
p = max([length(Gy) length(Acc)]);
q = min([length(Gy) length(Acc)]);
Acc = resample(Acc,q,p); %will always want to resample Acc

% Calculates the pitch and roll from Acc data
for i = 1:length(Acc)-1
    currAccPitch(i) = (atan2(Acc(i,2), Acc(i,3)) * 180/pi)+96-calib.Pitch;%added a random offest
    currAccRoll(i) = (atan2(-Acc(i,1), sqrt(Acc(i,2)*Acc(i,2) + Acc(i,3)*Acc(i,3))) * 180/pi)-calib.Roll;
end

% Calculates actual angle using Gyroscope and Acc Data (Complimentary
% Filter)
for idx = 1:length(Gy)-2
    currAngle.X(idx+1) = ((0.98*(currAngle.X(idx)+(Gy(idx+1,1)*dt)))+(0.02*currAccPitch(idx+1)));
    currAngle.Y(idx+1) = (currAngle.Y(idx) + (Gy(idx+1,2)*dt)); % Could high pass to cancel out drift?
    currAngle.Z(idx+1) = ((0.98*(currAngle.Z(idx) + (Gy(idx+1,3)*dt)))+(0.02*currAccRoll(idx+1)));
end

% Plots to visualise the tracking and effects of the complimentary filter
figure%('Name',sprintf('%s',num2str(LocAz),' degress in Azimuth and ',num2str(LocEle),...
    %'degrees in Elevation'))
t = 0:dt:((length(currAngle.X)-1)*dt);

plot(t,currAngle.X); hold on
plot(t,currAngle.Y);
plot(t,currAngle.Z);
plot(t,currAccRoll);
plot(t,currAccPitch);
% plot(t,Gy(2:end,1)); plot(t,Gy(2:end,2)); plot(t,Gy(2:end,3));
legend('X Pitch','Y Yaw','Z Roll','Roll','Pitch'); hold on
title('Tobii MEMs Data with Complimentary Filter')
xlabel('Time(s)')
ylabel('Angle (degrees)')
hold off

% Gets a mean response angle looking at last few data points
% Yaw = currAngle.Y, left is positive.
responseFBAz = mean(currAngle.Y(end-5:end));
% Ele = currAngle.X
responseFBEle = mean(currAngle.X(end-5:end));
toc
% profile off
% profile viewer
end