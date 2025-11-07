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
C_m=2.61e+08
H_im=4976.31
H_ow=261.06
C_iw=1.06e+07
a=0.277
p=0.17

% **环境数据**

% **太阳辐射计算**
Q_solar_mass = (1 - a) * p .* Q_solar_unit;  % 进入蓄热体的太阳辐射
Q_solar_indoor = a * p .* Q_solar_unit;        % 进入空气墙体综合的太阳辐射

%% **ODE方程定义**
odefun = @(t, Tm) (H_im * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Tm) + interp1(tspan, Q_solar_mass, t, 'linear', 'extrap')) / C_m;

% **初始值 [T_i, T_m]**
Y0 = T_actual(1);

% **求解 ODE**
[t, Tm] = ode45(odefun, tspan, Y0);

% 提取计算的温度结果
T_mass = Tm; 


dt = mean(diff(tspan));
T_smooth = sgolayfilt(T_actual, 3, 21); % 3阶 21点平滑
dTdt = movmean(diff(T_smooth), 3) / dt;
dTdt(end+1) = dTdt(end); % 补最后一点

%window_size = 5; % 5点滑动窗口

%T_smooth1 = movmean(T_actual, window_size); % 计算平滑后的温度
%re1 = gradient(T_smooth1, time_hours * 3600); % 计算平滑后的梯度

%poly_order = 3; % 多项式阶数
%frame_size = 11; % 滑动窗口大小
%T_smooth2 = sgolayfilt(T_actual, poly_order, frame_size); % SG 滤波
%re2 = gradient(T_smooth2, time_hours * 3600); % 计算梯度
%fs = 1 / 3600; % 采样频率（1 小时步长 -> Hz）
%fc = 1 / (24 * 3600); % 截止频率（24 小时周期）
%[b, a] = butter(4, fc / (fs / 2), 'low'); % 4阶 Butterworth 低通滤波器
%T_smooth3 = filtfilt(b, a, T_actual); % 低通滤波
%re3 = gradient(T_smooth3, time_hours * 3600); % 计算梯度
%sigma = 3; % 标准差，控制平滑程度
%T_smooth4 = imgaussfilt(T_actual, sigma); % 高斯滤波
%re4 = gradient(T_smooth4, time_hours * 3600); % 计算梯度



Q_heat = C_iw * dTdt - H_im * (T_mass - T_actual) - H_ow * (T_out - T_actual) - Q_solar_indoor + Q_infiltration;
Q_heat = movmean(Q_heat, 3);
