import requests
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
from sentence_transformers import SentenceTransformer

class BarcodeCO2():
    def __init__(self, barcode):
        self.food_co2_df = pd.read_csv('data/Food_CO2_Emissions_Dataset.csv')
        self.food_co2_df = self.food_co2_df.fillna(0)
        self.barcode = barcode
        self.base_url = "https://world.openfoodfacts.org/api/v0/product/"
        self.model = SentenceTransformer('all-MiniLM-L6-v2')

    def get_product_info(self):
        response = requests.get(f"{self.base_url}{self.barcode}.json")
        data = response.json()
        if data['status'] == 1:
            product = data['product']
            quantity = product.get("quantity", "").split()
            if (quantity == []):
                print('no weight data')
                return None
            
            weight = float(quantity[0])
            units = quantity[len(quantity) - 1]
            weight_kg = self.convert_weight_to_kg(weight, units)

            ingredient_percent = {}
            
            if (product.get('ingredients') == []):
                print('no ingredients')
                return None
            
            co2Food = {}

            for ingredient in product.get("ingredients"):
                ingredient_text = ingredient['text']
                percent = ingredient['percent_estimate']
                ingredient_percent[ingredient_text] = percent
                self.calculate_co2_emissions(co2Food, ingredient_text, weight_kg * (percent / 100))

            return co2Food

        else:
            print('item unable to be found')
            return None

    def calculate_co2_emissions(self, co2Food, other, weight):
        food_items = list(self.food_co2_df['Food product'])
        other_embedding = self.model.encode([other], convert_to_tensor=True).cpu().numpy()
        embeddings = self.model.encode(food_items, convert_to_tensor=True).cpu().numpy()
        similarities = cosine_similarity(other_embedding, embeddings).flatten()
        best_index = np.argmax(similarities)
        food_mapped_item = food_items[best_index]
        emissions = weight * self.food_co2_df.loc[self.food_co2_df['Food product'] == food_mapped_item, 'Total_emissions'].values[0]
        land_use = weight * self.food_co2_df.loc[self.food_co2_df['Food product'] == food_mapped_item, 'Land use per kilogram'].values[0]
        water_use = weight * self.food_co2_df.loc[self.food_co2_df['Food product'] == food_mapped_item, 'Scarcity-weighted water use per kilogram'].values[0]
        if emissions > 0.01:
            co2Food[food_mapped_item] = [float(emissions), float(water_use), float(land_use)]

    def convert_weight_to_kg(self, weight, units):
        if units == 'g':
            return weight * 0.001
        elif units == 'lb':
            return  weight * 0.453592
        elif units == 'oz':
            return weight * 0.0283495
        else:
            return weight
