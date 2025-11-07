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



C_w=1.11e+08
H_ow=330.37
H_window=0.00
H_iw=2773.43
C_i = 2.52e+05
C_m=3.96e+08
H_im=2645.63
a=0.246
p=5.65

C_w=2.20e+08
H_ow=266.43
H_window=78.47
H_iw=2150.17
C_i = 3.40e+06
C_m=1.12e+08
H_im=3390.39
a=0.927
p=8.30

C_wall=3.63e+08
H_ow=292.92
H_window=16.43
H_iw=2894.58
C_i = 8.85e+06
C_m=8.62e+07
H_im=1861.38
a=0.698
p=2.56




Q_solar_wall = a * p * Q_solar_unit;       % 进入空气部分
Q_solar_mass   = (1 - a) * p * Q_solar_unit; % 进入蓄热体部分

    % 插值函数
  

    % 微分方程：墙体温度
odefun = @(t, Y) [
        (H_ow * (interp1(tspan, T_out, t, 'linear', 'extrap') - Y(1)) + H_iw * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Y(1)) + ...
        interp1(tspan, Q_solar_wall, t, 'linear', 'extrap')) / C_w;
        (H_im * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Y(2)) + ...
        interp1(tspan, Q_solar_mass, t, 'linear', 'extrap')) / C_m;
        ];

% **初始值 [T_i, T_m]**
Y0 = [T_actual(1) - 2, T_actual(1)];

% **求解 ODE**
[t, Y] = ode45(odefun, tspan, Y0);

% 提取计算的温度结果
T_wall = Y(:,1);        % 蓄热体温度
T_mass = Y(:,2);

    % 平滑后求导
dt = mean(diff(tspan));
T_smooth = sgolayfilt(T_actual, 3, 21); % 3阶 21点平滑
dTdt = movmean(diff(T_smooth), 3) / dt;
dTdt(end+1) = dTdt(end); % 补最后一点

    % 反推热泵供热量
Q_heat = C_i * dTdt + H_iw * (T_actual - T_wall) + H_im * (T_actual - T_mass) + H_window*(T_actual - T_out)...
           + Q_infiltration;

Q_heat = movmean(Q_heat, 3);

