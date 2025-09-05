# 📈 AOL_AI – XAUUSD Trading AI

This project aims to build an **AI Trading Bot** based on **machine learning** for the **XAU/USD (Gold vs USD)** currency pair using the **M15 timeframe**.  
The system combines historical data, preprocessing, and a machine learning model (ONNX) to generate trading signals that can be automatically executed through **MetaTrader 5 (MQL5 Expert Advisor)**.

---

## 🚀 Key Features
- **XAU/USD Historical Data**: Uses M15 data since 2020.
- **Model Architectures**: Multiple deep learning architecture designs (see architecture files).
- **ONNX Model**: Final model exported in `ONNX` format for cross-platform compatibility.
- **MQL5 (MT5) Integration**: `AOL_AI.mq5` script acts as an Expert Advisor to execute trading signals directly in MetaTrader 5.
- **Analysis Notebook**: `AOL_AI.ipynb` for data preprocessing, exploration, model training, and evaluation.

---

## 🧠 Workflow
1. **Data Collection**  
   The historical XAU/USD M15 dataset (`XAUUSD_M15_DATA.csv`) contains:  
   - Timestamp  
   - Open, High, Low, Close (OHLC)  
   - Volume  

2. **Modeling**  
   - Multiple architectures were tested (`model1_architecture.png`, etc.).  
   - The final model was exported to **ONNX** format (`M15.XAUUSD.onnx`).

3. **Integration**  
   - `AOL_AI.mq5` loads the ONNX model → generates trading signals (BUY/SELL/HOLD).  
   - Automatically executed via MetaTrader 5 (MT5).

---

## ⚙️ How to Run
### 1. Train the Model (Optional)
- Open `AOL_AI.ipynb`
- Run all cells for preprocessing, training, and evaluation.
- The trained model will be saved as `M15.XAUUSD.onnx`.

### 2. Deploy to MetaTrader 5
- Copy `AOL_AI.mq5` into the `Experts` folder in MT5.
- Copy `M15.XAUUSD.onnx` into the `Files` folder in MT5.
- Attach the EA to the XAU/USD M15 chart.

---

## 📊 Dataset
- **Source**: Historical XAU/USD M15 data (2020–present).
- **Features**:  
  - OHLCV (Open, High, Low, Close, Volume)  
  - Time-based (timestamp)  
- **Goal**: Predict price movement direction (trading signal classification).

---

## 📌 Notes
- This project is still under development (experimental).  
- Backtesting and forward testing are required before live trading.  
- Trading risks remain the responsibility of the user.  

---
