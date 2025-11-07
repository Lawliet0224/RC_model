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

C_w=3.81e+08
C_c=3.12e+08
C_m=1.49e+07
C_i=9.73e+04
H_ow=4481.02
H_oc=81.67
H_iw=206.35
H_ic=3910.73
H_im=1949.97
H_window=0.00
a=0.799
p=0.27
r=0.985

C_w=3.96e+08
C_c=1.59e+08
C_m=1.88e+08
C_i=7.40e+06
H_ow=4149.20
H_oc=76.55
H_iw=35.45
H_ic=676.81
H_im=4891.99
H_window=190.99
a=0.934
p=8.46
r=0.739






% **环境数据**

% **太阳辐射计算**
Q_solar_wall = r * a * p * Q_solar_unit;       % 进入墙体部分
Q_solar_ceiling = (1 - r) * a * p * Q_solar_unit;       % 进入屋顶部分
Q_solar_mass   = (1 - a) * p * Q_solar_unit; % 进入蓄热体部分

%% **ODE方程定义**
T_out_fun = @(t) interp1(tspan, T_out, t, 'linear', 'extrap');
T_air_fun = @(t) interp1(tspan, T_actual, t, 'linear', 'extrap');
Q_wall_fun = @(t) interp1(tspan, Q_solar_wall, t, 'linear', 'extrap');
Q_ceil_fun = @(t) interp1(tspan, Q_solar_ceiling, t, 'linear', 'extrap');
Q_mass_fun = @(t) interp1(tspan, Q_solar_mass, t, 'linear', 'extrap');


odefun = @(t, Y) [
        (H_ow * (T_out_fun(t) - Y(1)) + H_iw * (T_air_fun(t) - Y(1)) + ...
        Q_wall_fun(t)) / C_w;
        (H_oc * (T_out_fun(t) - Y(2)) + H_ic * (T_air_fun(t) - Y(2)) + ...
        Q_ceil_fun(t)) / C_c;
        (H_im * (T_air_fun(t) - Y(3)) + Q_mass_fun(t)) / C_m; 
        ];

% **初始值 [T_i, T_m]**
Y0 = [T_actual(1)-1.5, T_actual(1)-1.5, T_actual(1)];

% **求解 ODE**
[t, Y] = ode45(odefun, tspan, Y0);

% 提取计算的温度结果
T_wall = Y(:,1);        % 蓄热体温度
T_ceiling = Y(:,2);
T_mass = Y(:,3);


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



Q_heat = C_i * dTdt + H_iw * (T_actual - T_wall) + H_ic * (T_actual - T_ceiling) + H_im * (T_actual - T_mass)  + H_window * (T_actual - T_out)...
           + Q_infiltration;
Q_heat = movmean(Q_heat, 3);

