clc; clear; close all;
rng('default'); % 保持随机数可重复
% 


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
Q_solar = data.SolarRadiation; % 单位面积太阳辐射 (W/m²)
Q_heatpump = data.HeatPump;   % 热泵供热量 (W)
Q_infiltration = data.Infiltration;
%% **参数定义**

C_w1=1.71e+08
H_iw=4659.49
H_ow=258.85
C_im=4.85e+06
a=0.985
p=6.16
H_window=61.91
C_w2=2.37e+08
H_w=2616.96


C_w1=6.21e+06
H_iw=4999.35
H_ow=2016.92
C_im=6.32e+05
a=0.965
p=1.89
H_window=0.00
C_w2=2.62e+08
H_w=348.64

C_w1=4.97e+07
H_iw=4859.20
H_ow=505.77
C_im=6.57e+06
a=0.999
p=22.42
H_window=83.89
C_w2=2.62e+08
H_w=545.33


%{
C_w1=1.98e+08
H_iw=4304.20
H_ow=1796.20
C_im=1.85e+06
a=0.990
p=73.87
H_window=123.33
C_w2=1.82e+08
H_w=196.97
%}

C_w1=1.06e+08
H_iw=4887.72
H_ow=371.15
C_im=4.21e+06
a=0.906
p=11.73
H_window=29.94
C_w2=2.41e+08
H_w=1245.90


% **环境数据**


    % 太阳辐射分配
    Q_solar_wall = a * p * Q_solar;       % 进入墙体部分Q1
    Q_solar_mass   = (1 - a) * p * Q_solar; % 进入空气蓄热体部分Q2

    % 插值函数


    % 微分方程：墙体温度
    odefun = @(t, Y)[
        (H_iw * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Y(1)) + H_w * (Y(2) - Y(1)) ) / C_w2;
        (H_ow * (interp1(tspan, T_out, t, 'linear', 'extrap') - Y(2)) + H_w * (Y(1) - Y(2)) + interp1(tspan, Q_solar_wall, t, 'linear', 'extrap')) / C_w1;
        ] ;

% **初始值 [T_i, T_m]**
    Y0 = [T_actual(1) - 1; T_actual(1) - 2];

% **求解 ODE**
    [t, Tm] = ode45(odefun, tspan, Y0);

% 提取计算的温度结果
    T_mid = Tm(:,1);        % 蓄热体温度
    T_wall = Tm(:,2);
    % 平滑后求导
    dt = mean(diff(tspan));
    T_smooth = sgolayfilt(T_actual, 3, 21); % 3阶 21点平滑
    dTdt = movmean(diff(T_smooth), 3) / dt;
    dTdt(end+1) = dTdt(end); % 补最后一点

    % 反推热泵供热量
    Q_heat = C_im * dTdt + H_iw * (T_actual - T_mid) + ...
         H_window * (T_actual - T_out) - Q_solar_mass + Q_infiltration;

    Q_heat = movmean(Q_heat, 3);
