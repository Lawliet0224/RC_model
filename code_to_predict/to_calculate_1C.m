clc; clear; close all;
rng('default'); % 保持随机数可重复
%{
opts = detectImportOptions('data_to_test/test_threeweek_data.xlsx');
opts.DataRange = '2:505';  % 让 MATLAB 以第二行开始读取数据
opts.VariableNames = {'Time', 'number', 'IndoorTemp', 'OutdoorTemp', ...
    'mean_volum', 'mean_tem_in', 'mean_tem_out', ...
    'Infiltration', 'Vent', 'HeatPump', 'SolarRadiation'};

data = readtable('data_to_test/test_threeweek_data.xlsx', opts);% 逐时数据
%}
% 时间 (小时) 转换为秒

opts = detectImportOptions('data_to_train/five_week_train_data_2_865.xlsx');
opts.DataRange = '2:865';  % 让 MATLAB 以第二行开始读取数据
opts.VariableNames = {'Time', 'number', 'IndoorTemp', 'OutdoorTemp', ...
    'mean_volum', 'mean_tem_in', 'mean_tem_out', ...
    'Infiltration', 'Vent', 'HeatPump', 'SolarRadiation'};

data = readtable('data_to_train/five_week_train_data_2_865.xlsx', opts);% 逐时数据


% 时间 (小时) 转换为秒
time_hours = data.Time;
tspan = time_hours * 3600; 

% 真实室内温度 (°C)
T_actual = data.IndoorTemp;

% 其他输入数据
T_out = data.OutdoorTemp;     % 室外温度 (°C)
Q_solar_unit = data.SolarRadiation; % 单位面积太阳辐射 (W/m²)
Q_heatpump = data.HeatPump;   % 热泵供热量 (W)
Q_infiltration = data.Infiltration;
%% **参数定义**
C_iwm=2.98e+07
H_ow=262.89
p=0.01


    % 太阳辐射分配
    Q_solar_wall =  p * Q_solar_unit;       % 进入空气部分

    % 平滑后求导
    dt = mean(diff(tspan));
    T_smooth = sgolayfilt(T_actual, 3, 21); % 3阶 21点平滑
    dTdt = movmean(diff(T_smooth), 3) / dt;
    dTdt(end+1) = dTdt(end); % 补最后一点

    % 反推热泵供热量
    Q_heat = C_iwm * dTdt + H_ow * (T_actual - T_out) - Q_solar_wall...
           + Q_infiltration;

    Q_heat = movmean(Q_heat, 3);

