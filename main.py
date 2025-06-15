from barcode_co2 import BarcodeCO2
from food_segmentation_co2 import FoodSegmentationCO2
from flask import Flask, request
import os

app = Flask(__name__)

@app.route('/get_co2_emissions_from_image', methods=['POST'])
def get_co2_emissions_from_image():
    upload_folder = 'temp_uploads'
    file = request.files['image']
    os.makedirs(upload_folder, exist_ok=True)
    file_path = os.path.join(upload_folder, file.filename)
    file.save(file_path)
    f = FoodSegmentationCO2()
    preds = f.make_preds(file_path)
    return preds

@app.route('/get_co2_emissions_from_barcode', methods=['GET', 'POST'])
def get_co2_emissions_from_barcode():
    barcode = request.args.get('code')
    b = BarcodeCO2(barcode)
    co2_data = b.get_product_info()
    return co2_data

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)