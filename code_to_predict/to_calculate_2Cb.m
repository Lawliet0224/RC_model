clc; clear; close all;
rng('default'); % 保持随机数可重复

opts = detectImportOptions('data_to_test/test_threeweek_data.xlsx');
opts.DataRange = '2:505';  % 让 MATLAB 以第二行开始读取数据
opts.VariableNames = {'Time', 'number', 'IndoorTemp', 'OutdoorTemp', ...
    'mean_volum', 'mean_tem_in', 'mean_tem_out', ...
    'Infiltration', 'Vent', 'HeatPump', 'SolarRadiation'};

data = readtable('data_to_test/test_threeweek_data.xlsx', opts);% 逐时数据

% 时间 (小时) 转换为秒
%{
opts = detectImportOptions('data_to_train/five_week_train_data_2_865.xlsx');
opts.DataRange = '2:865';  % 让 MATLAB 以第二行开始读取数据
opts.VariableNames = {'Time', 'number', 'IndoorTemp', 'OutdoorTemp', ...
    'mean_volum', 'mean_tem_in', 'mean_tem_out', ...
    'Infiltration', 'Vent', 'HeatPump', 'SolarRadiation'};

data = readtable('data_to_train/five_week_train_data_2_865.xlsx', opts);% 逐时数据
%}
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
C_w=2.72e+08
H_iw=4882.88
H_ow=280.05
C_im=2.72e+05
a=0.622
p=0.42

H_window=0.00


C_w=2.99e+08
H_iw=4920.24
H_ow=266.44
C_im=1.03e+05
a=0.163
p=0.14
H_window=12.00




% **环境数据**

% **太阳辐射计算**
Q_solar_mass = (1 - a) * p .* Q_solar_unit;  % 进入空气蓄热体的太阳辐射Q2
Q_solar_indoor = a * p .* Q_solar_unit;        % 进入墙体的太阳辐射Q1

%% **ODE方程定义**
odefun = @(t, Tm) (H_iw * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Tm) + H_ow * (interp1(tspan, T_out, t, 'linear', 'extrap') - Tm) + interp1(tspan, Q_solar_indoor, t, 'linear', 'extrap')) / C_w;


% **初始值 [T_i, T_m]**
Y0 = T_actual(1) - 1;

% **求解 ODE**
[t, Tm] = ode45(odefun, tspan, Y0);

% 提取计算的温度结果
T_wall = Tm; 


dt = mean(diff(tspan));
T_smooth = sgolayfilt(T_actual, 3, 21); % 3阶 21点平滑
dTdt = movmean(diff(T_smooth), 3) / dt;
dTdt(end+1) = dTdt(end); % 补最后一点

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



Q_heat = C_im * dTdt - H_iw * (T_wall - T_actual) - H_window * (T_out - T_actual) - Q_solar_mass + Q_infiltration;
Q_heat = movmean(Q_heat, 3);

