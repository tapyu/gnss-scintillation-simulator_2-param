%% Add the path to the libraries to current search path
path2directories=pwd;
path2Libraries=[path2directories,'/Libraries'];
addpath([path2Libraries,'/PropGeomCalc']);
addpath([path2Libraries,'/GenScintFieldRealization'])
addpath([path2Libraries,'/GPS_CoordinateXforms']);
addpath([path2Libraries,'/IGRF_Compston']);
addpath([path2Libraries,'/Utilities']);

%% User input parameters***************************************************
%Please specify date and time as [year month day hour minute second]
userInput.dateTime = [2014 01 01 10 00 00]; 

%Please choose data length for simulation\n (300s, 600s, or 900s)
userInput.length = 300;

% Please specify receiver position as [lat(rad), lon(rad), height(m)\n]'
userInput.RXPos = [-3.744466 -38.578404 59.6780]'; % long/lat targets the Teleinformatics Engineering department

% Please specify satellite PRN (0~32)
userInput.PRN = 0;

% Plotting figures of the simulated propagation geometry and scintillation intensity and phase? yes-1/no-0
userInput.plotSign = 1;

% Please specify how many GPS frequencies to simulate (1- GPS L1 only; 2 - GPS L1 and L2; 3 - GPS L1,L2, and L5)
userInput.frequencyNo = 3;

%% classes

% scintillation classes
K = 3; % number of S4/tau0 classes
S4s = [0.5, 1, 0.9];
tau0s = [0.7, 2, 0.25];

rx_vel = [0 100]; % receiver velocity

% list of field names for output
fields = {'S4_050_tau0_070_rxvel_static', 'S4_100_tau0_200_rxvel_static', 'S4_090_tau0_025_rxvel_static', 'S4_050_tau0_070_rxvel_dynamic', 'S4_100_tau0_200_rxvel_dynamic', 'S4_090_tau0_025_rxvel_dynamic'};

%% Start simulation
for v = 1:numel(rx_vel)
    %    V1 = east-west velocity on the earth arc (m/s, eastward +)
    %    V2 = north-south velocity on the earch arc (m/s, northward +)
    %    V3 = up-down velocity (m/s, up +)
    userInput.RXVel = [rx_vel(v) 0 0]';
    for k = 1:K % for all classes
        userInput.S4 = S4s(k); % S4 index (0~1)
        userInput.tau0 = tau0s(k); % Signal intensity decorrelation time in sec.

        %% Obtain the U and rhoVeff values based on the user input S4 and tau. 
        [U_mapped,rhoFVeff_mapped] = ParaMapping(userInput);
    
        %% Calculate the propagation geometry**************************************
        while true % try until an set of input parameters that allows for Vdrift computaiton
            try
                satGEOM = RunPropGeomCalc(userInput,rhoFVeff_mapped);
                break;
            catch ME
                if userInput.PRN < 32 % PRN
                    userInput.PRN = userInput.PRN + 1;
                else
                    userInput.PRN = 0;
                    if userInput.dateTime(4) < 24 % hour
                        userInput.dateTime(4) = userInput.dateTime(4) + 1;
                    else
                        userInput.dateTime(4) = 0;
                        if userInput.dateTime(3) < 29 % day
                            userInput.dateTime(3) = userInput.dateTime(3) + 1;
                        else
                           userInput.dateTime(3) = 1;
                           if userInput.dateTime(2) < 12 % month
                               userInput.dateTime(2) = userInput.dateTime(2) + 1;
                           else
                               userInput.dateTime(2) = 1;
                               if userInput.dateTime(1) <= year(datetime('now')) % year
                                   userInput.dateTime(1) = userInput.dateTime(1) + 1;
                               else
                                   newME = MException('Additional:ErrorOccurred', 'All years, days, months, and hours were tried, but without success.');
                                   newME = newME.addCause(ME);
                                   rethrow(newME);
                               end
                           end
                        end
                    end
                end
            end
                    % clc;
                    warning(['The provided receiver position, UTC time, and satellite PRN ' ...
                             'lead to a bad geometry for Vdrift estimation.\n\n' ...
                             'The input parameter has been changed and the the propagation ' ...
                             'geometry is computed again.']);
                    
                    fprintf(['running for PRN = %s\n' ...
                             'receiver velocity = %s\n' ...
                             'S4 = %s\n'...
                             'tau0 = %s\n'], ...
                             num2str(userInput.PRN), num2str(userInput.RXVel'), num2str(userInput.S4), num2str(userInput.tau0));
        end
        %% Generate scintillation signal field realizations
        [Scin_psi, Scin_amp, Scin_phi] = RunGenScintFieldRealization(userInput,satGEOM,U_mapped,rhoFVeff_mapped);
        scint_dataset.(fields{k + (v-1)*K}) = cat(1, reshape(Scin_amp, [1 size(Scin_amp)]), reshape(Scin_phi, [1 size(Scin_phi)]));
    end
end

scint_dataset.sampling_time_sec = .01; % check `Dt` in Libraries/GenScintFieldRealization/RunGenScintFieldRealization.m
scint_dataset.rx_pos_llh = userInput.RXPos;
scint_dataset.duration_sec = userInput.length;
scint_dataset.rx_vel_m_s = rx_vel(end);

save('scint_dataset.mat', 'scint_dataset');