import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.optimizers import Adam
from tqdm import tqdm
import os
import random
import tensorflow as tf

def set_seed(seed=42):
    np.random.seed(seed)
    random.seed(seed)
    tf.random.set_seed(seed)

set_seed(21)  # 设置所有随机种子


# ① 自定义 RMSE 损失（支持反向传播）
def rmse_loss(y_true, y_pred):
    # 注意：与 MSE 等价地找到同一最优点，只是刻度不同
    return tf.sqrt(tf.reduce_mean(tf.square(y_pred - y_true)))


def mape(y_true, y_pred):
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    nonzero_idx = y_true != 0  # 避免除以 0
    return np.mean(np.abs((y_true[nonzero_idx] - y_pred[nonzero_idx]) / y_true[nonzero_idx])) * 100

def r2_score(y_true, y_pred):
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    ss_res = np.sum((y_true - y_pred) ** 2)
    ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
    return 1 - (ss_res / ss_tot)

# ========== 1. 加载数据 ========== #
def load_data():
    train_df = pd.read_excel("data_to_train/five_week_train_data_2_865.xlsx")
    test_df = pd.read_excel("data_to_test/test_week_data.xlsx")
    return train_df, test_df

# ========== 2. 构造滚动窗口 ========== #
def build_window_data(df, feature_cols, target_col, window_size):
    X, y = [], []
    for i in range(len(df) - window_size):
        X.append(df[feature_cols].iloc[i:i+window_size].values)
        y.append(df[target_col].iloc[i + window_size])
    return np.array(X), np.array(y)

# ========== 3. 构建LSTM模型 ========== #
def build_lstm_model(input_shape):
    model = Sequential()
    model.add(LSTM(64, input_shape=input_shape))
    model.add(Dense(1))
    # ② 用自定义 rmse_loss 作为损失；附带把 RMSE 作为 metric 也显示出来
    model.compile(optimizer=Adam(0.01),
                  loss=rmse_loss,
                  metrics=[tf.keras.metrics.RootMeanSquaredError(name='rmse'),
                           tf.keras.metrics.MeanSquaredError(name='mse')])
    return model


# ========== 4. 主函数 ========== #
def main():
    train_df, test_df = load_data()
    feature_cols = ['OutdoorTemp', 'IndoorTemp', 'SolarRadiation',
                    'Infiltration', 'HeatingLoad']  # HeatingLoad用于构造滞后
    target_col = 'HeatingLoad'
    window_size = 24

    # 合并数据用于统一标准化
    full_df = pd.concat([train_df, test_df], axis=0).reset_index(drop=True)

    scaler = StandardScaler()
    full_scaled = full_df.copy()
    full_scaled[feature_cols] = scaler.fit_transform(full_scaled[feature_cols])

    # 划分标准化后的训练/测试集
    train_scaled = full_scaled.iloc[:len(train_df)].reset_index(drop=True)
    test_scaled = full_scaled.iloc[len(train_df) - window_size:].reset_index(drop=True)

    # 构造训练集窗口
    X_train, y_train = build_window_data(train_scaled, feature_cols, target_col, window_size)
    model = build_lstm_model(input_shape=(X_train.shape[1], X_train.shape[2]))
    model.fit(X_train, y_train, epochs=30, batch_size=16, verbose=1)
    # 提前定义 mean 和 std（在 fit 之后立即做）
    heating_idx = feature_cols.index('HeatingLoad')
    mean_train = scaler.mean_[heating_idx]
    std_train = np.sqrt(scaler.var_[heating_idx])

    # -------- 训练集预测部分 -------- #
    X_train_pred = model.predict(X_train).flatten()
    y_train_real = y_train * std_train + mean_train
    y_train_pred_real = X_train_pred * std_train + mean_train

    # -------- 训练集误差指标 -------- #
    mae_train = np.mean(np.abs(y_train_real - y_train_pred_real))
    rmse_train = np.sqrt(np.mean((y_train_real - y_train_pred_real) ** 2))
    mape_train = mape(y_train_real, y_train_pred_real)
    r2_train = r2_score(y_train_real, y_train_pred_real)

    # 滚动预测测试集
    X_test, y_test = build_window_data(test_scaled, feature_cols, target_col, window_size)
    y_pred = model.predict(X_test).flatten()

    # 还原预测值（逆标准化）
    heating_idx = feature_cols.index('HeatingLoad')
    mean = scaler.mean_[heating_idx]
    std = np.sqrt(scaler.var_[heating_idx])
    y_pred_real = y_pred * std + mean
    y_test_real = y_test * std + mean
    print("Time_Index length:", len(test_df['Time'].iloc[window_size:]))
    print("y_test_real length:", len(y_test_real))
    print("y_pred_real length:", len(y_pred_real))
    # 保存结果
    result_df = pd.DataFrame({
        'Actual_HeatingLoad': y_test_real,
        'Predicted_HeatingLoad': y_pred_real
    })

    os.makedirs("dataresult", exist_ok=True)
    result_df.to_excel("data_to_result/lstm_5t1t.xlsx", index=False)


    # 误差指标
    mae = np.mean(np.abs(y_test_real - y_pred_real))
    rmse = np.sqrt(np.mean((y_test_real - y_pred_real) ** 2))
    mape_test = mape(y_test_real, y_pred_real)
    r2_test = r2_score(y_test_real, y_pred_real)

    print(f"📊 MAE: {mae:.2f} W, RMSE: {rmse:.2f} W")

    print(f"\n📊【训练集】")
    print(f"MAE:  {mae_train:.2f} W")
    print(f"RMSE: {rmse_train:.2f} W")
    print(f"MAPE: {mape_train:.2f}%")
    print(f"R²:   {r2_train:.4f}")

    print(f"\n📊【测试集】")
    print(f"MAE:  {mae:.2f} W")
    print(f"RMSE: {rmse:.2f} W")
    print(f"MAPE: {mape_test:.2f}%")
    print(f"R²:   {r2_test:.4f}")


if __name__ == "__main__":
    main()
