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
C_w1=3.33e+07
H_iw=4964.82
H_ow=397.60
C_i=3.44e+05
a=0.116
p=33.77
H_window=0.00
C_w2=2.62e+08
H_w=1858.94
H_im=45.71
C_m=4.56e+08

C_w1=9.00e+07
H_iw=4598.18
H_ow=1598.18
C_i=4.66e+06
a=0.820
p=39.57
H_window=145.09
C_w2=1.52e+08
H_w=218.25
H_im=920.45
C_m=1.8e+08



% **环境数据**


    % 太阳辐射分配
    Q_solar_wall = a * p * Q_solar;       % 进入墙体部分Q1
    Q_solar_mass   = (1 - a) * p * Q_solar; % 进入空气蓄热体部分Q2

    % 插值函数


    % 微分方程：墙体温度
    odefun = @(t, Y)[
        (H_iw * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Y(1)) + H_w * (Y(2) - Y(1)) ) / C_w2;
        (H_ow * (interp1(tspan, T_out, t, 'linear', 'extrap') - Y(2)) + H_w * (Y(1) - Y(2)) + interp1(tspan, Q_solar_wall, t, 'linear', 'extrap')) / C_w1;
        (interp1(tspan, Q_solar_mass, t, 'linear', 'extrap') + H_im * (interp1(tspan, T_actual, t, 'linear', 'extrap') - Y(3))) / C_m;
        ] ;

% **初始值 [T_i, T_m]**
    Y0 = [T_actual(1) - 1; T_actual(1) - 2; T_actual(1)];

% **求解 ODE**
    [t, Tm] = ode45(odefun, tspan, Y0);

% 提取计算的温度结果
    T_mid = Tm(:,1);        % 蓄热体温度
    T_wall = Tm(:,2);
    T_mass = Tm(:,3);
    % 平滑后求导
    dt = mean(diff(tspan));
    T_smooth = sgolayfilt(T_actual, 3, 21); % 3阶 21点平滑
    dTdt = movmean(diff(T_smooth), 3) / dt;
    dTdt(end+1) = dTdt(end); % 补最后一点

    % 反推热泵供热量
    Q_heat = C_i * dTdt + H_iw * (T_actual - T_mid) + H_im * (T_actual - T_mass) + ...
         H_window * (T_actual - T_out)  + Q_infiltration;
    Q_heat = movmean(Q_heat, 3);


