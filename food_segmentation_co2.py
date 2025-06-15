import torch
import segmentation_models_pytorch as smp
from PIL import Image
from torchvision import transforms
import data.foodseg103_to_co2 as foodseg103_to_co2
import pandas as pd

class FoodSegmentationCO2:
    def __init__(self):
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        self.model = smp.UPerNet(
            encoder_name='resnet50',
            encoder_weights=None,
            in_channels=3,
            classes=104,
            encoder_depth=5,
            decoder_channels=256
        )
        self.model.to(self.device)
        if (self.device == 'cuda'):
            self.model.load_state_dict(torch.load('models/best_model.pth'))
        else:
            self.model.load_state_dict(torch.load('models/best_model.pth', map_location=torch.device('cpu')))

        self.df = pd.read_csv('data/Food_CO2_Emissions_Dataset.csv')
        self.df = self.df.fillna(0)

    def make_preds(self, img_path):
        img_transform = transforms.Compose([
            transforms.Resize((256, 256)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])

        image = Image.open(img_path).convert("RGB")
        input = img_transform(image).unsqueeze(0).to(self.device)

        self.model.eval()

        with torch.no_grad():
            output = self.model(input)
            probs = torch.softmax(output, dim=1)
            confidence, pred_mask = torch.max(probs, dim=1)
            pred_mask = pred_mask.squeeze(0).cpu()
            confidence = confidence.squeeze(0).cpu()

            confidence_threshold = 0.35
            pred_mask[confidence < confidence_threshold] = 0

        return self.calculate_co2_emissions(pred_mask)

    def get_pixel_frequency(self, pred_mask):
        class_counts = torch.bincount(pred_mask.flatten(), minlength=104)
        threshold = 256 * 256 * 0.01
        frequency = {i: int(count) for i, count in enumerate(class_counts) if count > threshold and i != 0}
        print(frequency)
        index_to_label = {
            foodseg103_to_co2.foodseg103_to_co2_category[str(index)]: label_id
            for index, label_id in frequency.items()
        }
        return index_to_label
    
    def calculate_co2_emissions(self, pred_mask):
        pixel_to_cm = 0.25
        thickness = 1
        index_to_label = self.get_pixel_frequency(pred_mask)
        d = {}
        for key, val in index_to_label.items():
            print(key)
            emissions_per_kg = list(self.df[self.df['Food product'] == key]['Total_emissions'])[0]
            land_use_per_kg = list(self.df[self.df['Food product'] == key]['Land use per kilogram'])[0]
            water_use_per_kg = list(self.df[self.df['Food product'] == key]['Scarcity-weighted water use per kilogram'])[0]
            density = list(self.df[self.df['Food product'] == key]['Density (g/cm^3)'])[0]
            print(key, emissions_per_kg, density)
            weight = pixel_to_cm**2 * thickness * val * (density / 1000)
            co2 = weight * emissions_per_kg
            land_use = weight * land_use_per_kg
            water_use = weight * water_use_per_kg
            d[key] = [co2, water_use, land_use]
        return d
