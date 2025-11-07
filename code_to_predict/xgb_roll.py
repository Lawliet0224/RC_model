import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from xgboost import XGBRegressor
from tqdm import tqdm
import os

# ========== 误差函数定义 ========== #
def mape(y_true, y_pred):
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    nonzero_idx = y_true != 0
    return np.mean(np.abs((y_true[nonzero_idx] - y_pred[nonzero_idx]) / y_true[nonzero_idx])) * 100

def r2_score(y_true, y_pred):
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    ss_res = np.sum((y_true - y_pred) ** 2)
    ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
    return 1 - (ss_res / ss_tot)

# ========== 1. 加载数据 ========== #
def load_data():
    train_df = pd.read_excel("data_to_train/nine_week_train_data_2_1585.xlsx")
    test_df = pd.read_excel("data_to_test/test_week_data.xlsx")

    train_df = train_df.loc[:, ~train_df.columns.str.contains('^Unnamed')]
    test_df = test_df.loc[:, ~test_df.columns.str.contains('^Unnamed')]

    train_df = train_df.sort_values("Time").reset_index(drop=True)
    test_df = test_df.sort_values("Time").reset_index(drop=True)

    return train_df, test_df

# ========== 2. 特征工程 ========== #
def create_features(df):
    df_feat = df.copy()
    if len(df_feat) <= 24:
        return None
    df_feat['lag_HeatingLoad'] = df_feat['HeatingLoad'].shift(24)
    df_feat['lag_IndoorTemp'] = df_feat['IndoorTemp'].shift(24)
    df_feat = df_feat.dropna()
    return df_feat if len(df_feat) >= 24 else None

# ========== 3. 主函数 ========== #
def main():
    train_df, test_df = load_data()
    print(f"✅ 数据加载完成 | 训练集: {len(train_df)} 小时 | 测试集: {len(test_df)} 小时")

    TRAIN_WINDOW = 864
    HOURS_PER_DAY = 24
    num_days = int(np.ceil(len(test_df) / HOURS_PER_DAY))

    feature_cols = ['OutdoorTemp', 'IndoorTemp', 'SolarRadiation',
                    'Infiltration', 'lag_HeatingLoad', 'lag_IndoorTemp']

    scaler = StandardScaler()
    train_processed_full = create_features(train_df.copy())
    scaler.fit(train_processed_full[feature_cols])

    predictions = []
    actuals = []
    time_indices = []

    final_model = None
    last_train_y_true = None
    last_train_y_pred = None

    pbar = tqdm(range(num_days), desc="滚动预测")
    for day in pbar:
        start = day * HOURS_PER_DAY
        end = min((day + 1) * HOURS_PER_DAY, len(test_df))
        test_day = test_df.iloc[start:end].copy()

        if day == 0:
            lag_source = train_df.iloc[-HOURS_PER_DAY:]
        else:
            lag_source = test_df.iloc[(day - 1) * HOURS_PER_DAY: day * HOURS_PER_DAY]

        test_day['lag_HeatingLoad'] = lag_source['HeatingLoad'].values[:len(test_day)]
        test_day['lag_IndoorTemp'] = lag_source['IndoorTemp'].values[:len(test_day)]

        train_processed = create_features(train_df)
        if train_processed is None:
            print(f"⚠️ 第 {day+1} 天训练数据不足，跳过")
            continue

        X_train = scaler.transform(train_processed[feature_cols])
        y_train = train_processed['HeatingLoad'].values
        X_test = scaler.transform(test_day[feature_cols])

        model = XGBRegressor(
            n_estimators=300,
            max_depth=6,
            learning_rate=0.01,
            subsample=0.8,
            random_state=42,
            reg_lambda = 5

        )
        model.fit(X_train, y_train)
        final_model = model

        y_pred = model.predict(X_test)
        predictions.extend(y_pred)
        actuals.extend(test_day['HeatingLoad'].values)
        time_indices.extend(test_day['Time'].values[:len(test_day)])

        if day == num_days - 1:
            last_train_y_true = y_train
            last_train_y_pred = model.predict(X_train)

        train_df = pd.concat([
            train_df.iloc[HOURS_PER_DAY:],
            test_day
        ])
        print(f"[DEBUG] Day {day+1}: train_df size = {len(train_df)}, NA counts =\n{train_df.isna().sum()}")

    result_df = pd.DataFrame({
        'Time_Index': time_indices,
        'Actual_HeatingLoad': actuals,
        'Predicted_HeatingLoad': predictions
    })

    os.makedirs("dataresult", exist_ok=True)
    save_path = "data_to_result/xgboost_3t1t.xlsx"
    result_df.to_excel(save_path, index=False)

    mae_test = np.mean(np.abs(np.array(actuals) - np.array(predictions)))
    rmse_test = np.sqrt(np.mean((np.array(actuals) - np.array(predictions)) ** 2))
    mape_test = mape(actuals, predictions)
    r2_test = r2_score(actuals, predictions)

    mae_train = np.mean(np.abs(last_train_y_true - last_train_y_pred))
    rmse_train = np.sqrt(np.mean((last_train_y_true - last_train_y_pred) ** 2))
    mape_train = mape(last_train_y_true, last_train_y_pred)
    r2_train = r2_score(last_train_y_true, last_train_y_pred)

    print(f"\n📊【训练集】")
    print(f"MAE:  {mae_train:.2f} W")
    print(f"RMSE: {rmse_train:.2f} W")
    print(f"MAPE: {mape_train:.2f}%")
    print(f"R²:   {r2_train:.4f}")

    print(f"\n📊【测试集】")
    print(f"MAE:  {mae_test:.2f} W")
    print(f"RMSE: {rmse_test:.2f} W")
    print(f"MAPE: {mape_test:.2f}%")
    print(f"R²:   {r2_test:.4f}")

if __name__ == "__main__":
    main()
