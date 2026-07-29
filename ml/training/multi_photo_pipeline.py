"""
Multi-Photo Ensemble Prediction Pipeline for Oral Cancer Screening
Analyzes 5 photos and combines predictions for higher accuracy
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
from typing import List, Dict, Tuple
from dataclasses import dataclass
from enum import Enum

class RiskLevel(Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"

class PhotoType(Enum):
    FRONT_VIEW = 0
    RIGHT_CHEEK = 1
    LEFT_CHEEK = 2
    TONGUE = 3
    PALATE = 4

@dataclass
class PhotoResult:
    photo_type: PhotoType
    prediction: np.ndarray  # Class probabilities
    confidence: float
    quality_score: float
    risk_level: RiskLevel
    detected_areas: List[Dict] = None

@dataclass
class ScreeningResult:
    overall_risk: RiskLevel
    overall_confidence: float
    photo_results: List[PhotoResult]
    recommendations: List[str]
    specialist_required: bool
    urgency_level: str  # 'routine', 'soon', 'urgent'

class MultiPhotoOralScreening:
    """
    Ensemble prediction system using 5 photos for comprehensive screening
    """
    
    def __init__(self, model_path: str):
        self.model = keras.models.load_model(model_path)
        self.class_names = ['Healthy', 'Benign', 'OPMD', 'OCA']
        
        # Photo-specific weights (some areas more critical)
        self.photo_weights = {
            PhotoType.FRONT_VIEW: 1.0,
            PhotoType.RIGHT_CHEEK: 1.2,  # Inner cheeks critical
            PhotoType.LEFT_CHEEK: 1.2,
            PhotoType.TONGUE: 1.3,       # Tongue most critical
            PhotoType.PALATE: 1.1
        }
        
        # Risk thresholds
        self.risk_thresholds = {
            'low': 0.3,      # < 30% suspicious
            'moderate': 0.6,  # 30-60% suspicious
            'high': 0.6       # > 60% suspicious
        }
    
    def assess_photo_quality(self, image: np.ndarray) -> Dict[str, float]:
        """
        Assess photo quality before prediction
        Returns dict with quality metrics
        """
        # Brightness check
        brightness = np.mean(image)
        brightness_score = 1.0 if 80 < brightness < 200 else 0.5
        
        # Sharpness check (Laplacian variance)
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        sharpness_score = min(laplacian_var / 100, 1.0)
        
        # Contrast check
        contrast = np.std(gray)
        contrast_score = min(contrast / 50, 1.0)
        
        # Overall quality score
        overall_score = (
            0.3 * brightness_score +
            0.4 * sharpness_score +
            0.3 * contrast_score
        )
        
        return {
            'brightness': brightness_score,
            'sharpness': sharpness_score,
            'contrast': contrast_score,
            'overall': overall_score,
            'acceptable': overall_score > 0.6
        }
    
    def preprocess_image(self, image: np.ndarray) -> np.ndarray:
        """Preprocess image for model input"""
        # Resize to model input size
        image = cv2.resize(image, (224, 224))
        
        # Normalize to [0, 1]
        image = image.astype(np.float32) / 255.0
        
        # Add batch dimension
        image = np.expand_dims(image, axis=0)
        
        return image
    
    def predict_single_photo(
        self, 
        image: np.ndarray, 
        photo_type: PhotoType
    ) -> PhotoResult:
        """
        Predict on a single photo
        """
        # Quality check
        quality = self.assess_photo_quality(image)
        
        if not quality['acceptable']:
            return PhotoResult(
                photo_type=photo_type,
                prediction=None,
                confidence=0.0,
                quality_score=quality['overall'],
                risk_level=None,
                detected_areas=None
            )
        
        # Preprocess and predict
        preprocessed = self.preprocess_image(image)
        prediction = self.model.predict(preprocessed, verbose=0)[0]
        
        # Calculate confidence (max probability)
        confidence = float(np.max(prediction))
        
        # Determine risk level
        # Classes: 0=Healthy, 1=Benign, 2=OPMD, 3=OCA
        suspicious_prob = prediction[2] + prediction[3]  # OPMD + OCA
        
        if suspicious_prob < self.risk_thresholds['low']:
            risk_level = RiskLevel.LOW
        elif suspicious_prob < self.risk_thresholds['moderate']:
            risk_level = RiskLevel.MODERATE
        else:
            risk_level = RiskLevel.HIGH
        
        return PhotoResult(
            photo_type=photo_type,
            prediction=prediction,
            confidence=confidence,
            quality_score=quality['overall'],
            risk_level=risk_level
        )
    
    def ensemble_prediction(
        self, 
        photos: List[Tuple[np.ndarray, PhotoType]]
    ) -> ScreeningResult:
        """
        Perform ensemble prediction on all 5 photos
        
        Args:
            photos: List of (image, photo_type) tuples
        
        Returns:
            ScreeningResult with comprehensive analysis
        """
        photo_results = []
        valid_predictions = []
        valid_weights = []
        
        # Predict on each photo
        for image, photo_type in photos:
            result = self.predict_single_photo(image, photo_type)
            photo_results.append(result)
            
            if result.prediction is not None:
                # Weight by photo importance and quality
                weight = (
                    self.photo_weights[photo_type] * 
                    result.quality_score
                )
                valid_predictions.append(result.prediction)
                valid_weights.append(weight)
        
        # Check if we have enough valid photos
        if len(valid_predictions) < 3:
            return ScreeningResult(
                overall_risk=None,
                overall_confidence=0.0,
                photo_results=photo_results,
                recommendations=['Please retake photos with better quality'],
                specialist_required=False,
                urgency_level='none'
            )
        
        # Weighted ensemble prediction
        weights_normalized = np.array(valid_weights) / sum(valid_weights)
        ensemble_pred = np.average(valid_predictions, weights=weights_normalized, axis=0)
        
        # Calculate overall metrics
        overall_confidence = float(np.max(ensemble_pred))
        predicted_class = np.argmax(ensemble_pred)
        
        # Determine overall risk
        suspicious_prob = ensemble_pred[2] + ensemble_pred[3]
        
        if suspicious_prob < self.risk_thresholds['low']:
            overall_risk = RiskLevel.LOW
            urgency = 'routine'
            specialist_required = False
        elif suspicious_prob < self.risk_thresholds['moderate']:
            overall_risk = RiskLevel.MODERATE
            urgency = 'soon'
            specialist_required = True
        else:
            overall_risk = RiskLevel.HIGH
            urgency = 'urgent'
            specialist_required = True
        
        # Generate recommendations
        recommendations = self._generate_recommendations(
            overall_risk, 
            photo_results, 
            ensemble_pred
        )
        
        return ScreeningResult(
            overall_risk=overall_risk,
            overall_confidence=overall_confidence,
            photo_results=photo_results,
            recommendations=recommendations,
            specialist_required=specialist_required,
            urgency_level=urgency
        )
    
    def _generate_recommendations(
        self, 
        risk_level: RiskLevel, 
        photo_results: List[PhotoResult],
        ensemble_pred: np.ndarray
    ) -> List[str]:
        """Generate personalized recommendations"""
        recommendations = []
        
        if risk_level == RiskLevel.LOW:
            recommendations.extend([
                "No concerning signs detected",
                "Continue regular oral hygiene",
                "Schedule routine dental checkup",
                "Rescreen in 3 months"
            ])
        
        elif risk_level == RiskLevel.MODERATE:
            recommendations.extend([
                "Some changes detected that need attention",
                "Schedule appointment with dentist within 2-4 weeks",
                "Avoid tobacco and alcohol",
                "Monitor any changes closely"
            ])
            
            # Identify which photos showed issues
            problem_photos = [
                r.photo_type.name for r in photo_results 
                if r.risk_level in [RiskLevel.MODERATE, RiskLevel.HIGH]
            ]
            if problem_photos:
                recommendations.append(
                    f"Pay special attention to: {', '.join(problem_photos)}"
                )
        
        else:  # HIGH risk
            recommendations.extend([
                "⚠️ Concerning changes detected",
                "URGENT: See oral surgeon or oncologist within 1 week",
                "Bring this report to your appointment",
                "Early detection significantly improves outcomes"
            ])
        
        return recommendations
    
    def generate_report(self, result: ScreeningResult) -> Dict:
        """
        Generate comprehensive report for user/doctor
        """
        report = {
            'screening_date': datetime.now().isoformat(),
            'overall_assessment': {
                'risk_level': result.overall_risk.value if result.overall_risk else 'unknown',
                'confidence': f"{result.overall_confidence * 100:.1f}%",
                'urgency': result.urgency_level,
                'specialist_required': result.specialist_required
            },
            'photo_by_photo': [],
            'recommendations': result.recommendations,
            'disclaimer': (
                "This screening is for early warning only and is not a "
                "medical diagnosis. Professional evaluation is essential "
                "for any concerning findings."
            )
        }
        
        # Add individual photo results
        for photo_result in result.photo_results:
            if photo_result.prediction is not None:
                report['photo_by_photo'].append({
                    'area': photo_result.photo_type.name,
                    'status': photo_result.risk_level.value,
                    'confidence': f"{photo_result.confidence * 100:.1f}%",
                    'quality': f"{photo_result.quality_score * 100:.1f}%",
                    'class_probabilities': {
                        'Healthy': f"{photo_result.prediction[0] * 100:.1f}%",
                        'Benign': f"{photo_result.prediction[1] * 100:.1f}%",
                        'OPMD': f"{photo_result.prediction[2] * 100:.1f}%",
                        'OCA': f"{photo_result.prediction[3] * 100:.1f}%"
                    }
                })
            else:
                report['photo_by_photo'].append({
                    'area': photo_result.photo_type.name,
                    'status': 'quality_issue',
                    'message': 'Photo quality insufficient for analysis'
                })
        
        return report


# Example usage
def demo_multi_photo_screening():
    """
    Demonstration of multi-photo screening workflow
    """
    # Initialize screening system
    screener = MultiPhotoOralScreening(model_path='oral_cavity_model.tflite')
    
    # Simulated photo capture (in real app, these come from camera)
    photos = [
        (load_image('photo1_front.jpg'), PhotoType.FRONT_VIEW),
        (load_image('photo2_right.jpg'), PhotoType.RIGHT_CHEEK),
        (load_image('photo3_left.jpg'), PhotoType.LEFT_CHEEK),
        (load_image('photo4_tongue.jpg'), PhotoType.TONGUE),
        (load_image('photo5_palate.jpg'), PhotoType.PALATE),
    ]
    
    # Perform screening
    result = screener.ensemble_prediction(photos)
    
    # Generate report
    report = screener.generate_report(result)
    
    # Display results
    print("=== Screening Results ===")
    print(f"Overall Risk: {result.overall_risk.value.upper()}")
    print(f"Confidence: {result.overall_confidence * 100:.1f}%")
    print(f"\nRecommendations:")
    for rec in result.recommendations:
        print(f"  • {rec}")
    
    # Save report as JSON
    with open('screening_report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    return result


# Confidence calibration for better UX
class ConfidenceCalibrator:
    """
    Calibrate model confidence scores for better user communication
    """
    
    @staticmethod
    def calibrate_confidence(raw_confidence: float, risk_level: RiskLevel) -> str:
        """
        Convert raw confidence to user-friendly message
        """
        if risk_level == RiskLevel.LOW:
            if raw_confidence > 0.9:
                return "Very confident - no concerns detected"
            elif raw_confidence > 0.75:
                return "Confident - appears healthy"
            else:
                return "Likely healthy - continue monitoring"
        
        elif risk_level == RiskLevel.MODERATE:
            if raw_confidence > 0.8:
                return "Some changes detected - professional review recommended"
            else:
                return "Unclear findings - professional evaluation needed"
        
        else:  # HIGH
            if raw_confidence > 0.85:
                return "Concerning findings - urgent evaluation required"
            else:
                return "Suspicious changes - see specialist immediately"
    
    @staticmethod
    def get_next_steps(result: ScreeningResult) -> Dict[str, str]:
        """
        Provide clear next steps based on results
        """
        if result.overall_risk == RiskLevel.LOW:
            return {
                'timeline': 'Schedule routine dental checkup within 6 months',
                'action': 'Continue healthy habits',
                'rescreen': 'Rescreen in 3 months'
            }
        
        elif result.overall_risk == RiskLevel.MODERATE:
            return {
                'timeline': 'See dentist within 2-4 weeks',
                'action': 'Avoid tobacco and alcohol',
                'rescreen': 'Follow dentist recommendations'
            }
        
        else:  # HIGH
            return {
                'timeline': 'Contact oral surgeon within 1 week',
                'action': 'Bring this report to appointment',
                'rescreen': 'As directed by specialist'
            }


if __name__ == "__main__":
    demo_multi_photo_screening()