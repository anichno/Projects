package com.anthonyenterprises.carboplatincalc;

import com.anthonyenterprises.carboplatincalc.R;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemSelectedListener;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.ViewFlipper;

public class CarboplatinCalc extends Activity {
	
	final String PREFS_NAME = "CarboplatinPrefs";
	
	Button btn;
	Button clrBtn;
	ViewFlipper flip;
	
	EditText ageText;
	EditText scrText;
	EditText heightText;
	EditText weightText;
	EditText aucText;
	
	TextView totalBWClearanceResultView;
	TextView totalBWResultView;
	TextView idealBWClearanceResultView;
	TextView idealBWResultView;
	TextView adjustedBWClearanceResultView;
	TextView adjustedBWResultView;
	
	Spinner sexSpinner;
	Spinner heightSpinner;
	Spinner weightSpinner;
	
	boolean maleSelected = true;
	boolean poundsSelected = true;
	boolean inchesSelected = true;
	
	
	public void onCreate(Bundle savedInstanceState) {
	    super.onCreate(savedInstanceState);
	    setContentView(R.layout.main);
	    
	    btn=(Button)findViewById(R.id.btn);
	    clrBtn = (Button)findViewById(R.id.clrBtn);
	    
	    flip=(ViewFlipper)findViewById(R.id.flip);
	    
	    ageText=(EditText)findViewById(R.id.ageText);
	    scrText=(EditText)findViewById(R.id.scrText);
	    heightText=(EditText)findViewById(R.id.heightText);
	    weightText=(EditText)findViewById(R.id.weightText);
	    aucText=(EditText)findViewById(R.id.aucText);
	    
	    totalBWClearanceResultView=(TextView)findViewById(R.id.totalBWClearanceResultView);
	    totalBWResultView=(TextView)findViewById(R.id.totalBWResultView);
	    idealBWClearanceResultView=(TextView)findViewById(R.id.idealBWClearanceResultView);
	    idealBWResultView=(TextView)findViewById(R.id.idealBWResultView);
	    adjustedBWClearanceResultView=(TextView)findViewById(R.id.adjustedBWClearanceResultView);
	    adjustedBWResultView=(TextView)findViewById(R.id.adjustedBWResultView);
	    
	    sexSpinner = (Spinner) findViewById(R.id.sexSpinner);
	    ArrayAdapter<CharSequence> sexAdapter = ArrayAdapter.createFromResource(
	            this, R.array.gender_array, android.R.layout.simple_spinner_item);
	    sexAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
	    sexSpinner.setAdapter(sexAdapter);
	    sexSpinner.setOnItemSelectedListener(new GenderSelectedListener());
	    
	    SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
	    
	    heightSpinner = (Spinner) findViewById(R.id.heightSpinner);
	    ArrayAdapter<CharSequence> heightAdapter = ArrayAdapter.createFromResource(
	            this, R.array.height_array, android.R.layout.simple_spinner_item);
	    heightAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
	    heightSpinner.setAdapter(heightAdapter);
	    heightSpinner.setOnItemSelectedListener(new HeightSelectedListener());
	    
	    inchesSelected = settings.getBoolean("heightunits", true);
	    if (inchesSelected) {
	    	heightSpinner.setSelection(0);
	    }
	    else {
	    	heightSpinner.setSelection(1);
	    }
	    
	    weightSpinner = (Spinner) findViewById(R.id.weightSpinner);
	    ArrayAdapter<CharSequence> weightAdapter = ArrayAdapter.createFromResource(
	            this, R.array.weight_array, android.R.layout.simple_spinner_item);
	    weightAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
	    weightSpinner.setAdapter(weightAdapter);
	    weightSpinner.setOnItemSelectedListener(new WeightSelectedListener());
	    
	    poundsSelected = settings.getBoolean("weightunits", true);
	    if (poundsSelected) {
	    	weightSpinner.setSelection(0);
	    }
	    else {
	    	weightSpinner.setSelection(1);
	    }
	}

	public void ClickHandler(View v) {
		int age = 0;
		double scr = 0;
		double height = 0;
		double weight = 0;
		double auc = 0;
		
		try {
			age = Integer.parseInt(ageText.getText().toString());
			scr = Double.parseDouble(scrText.getText().toString());
			height = Double.parseDouble(heightText.getText().toString());
			weight = Double.parseDouble(weightText.getText().toString());
			auc = Double.parseDouble(aucText.getText().toString());
		} catch (Exception e) {
			Log.e("Button","fail");
			return;
		}
		
		 
		// 1 pound = 0.45359237 kilograms	
		if (poundsSelected) {
			weight *= 0.45359237d;
		}
		
		// 1 inch = 2.54 cm
		if (!inchesSelected) {
			height /= 2.54d;
		}
		 
		// Cockcroft and Gault estimated clearance equation
		// Male: CrCl (ml/min) = (140 - age) x wt (kg) / (serum creatinine x 72) 
		// Female: Multiply above result by 0.85
		 
		 
		 // Ideal body weight (IBW):
		 // IBW (males) = 50 kg + 2.3 x (height [inches] - 60)
		 // IBW (females) = 45.5 kg + 2.3 x (height [inches] - 60)
		 
		 double idealBodyWeight = 50 + 2.3d * (height - 60);
		 double idealBWClearanceResult = (140-age) * idealBodyWeight / (scr*72);
		 if (!maleSelected) {
			 idealBWClearanceResult *= 0.85d;
		 }
		 idealBWClearanceResultView.setText("CrCl (ml/min):\t" + Long.toString(Math.round(idealBWClearanceResult)));
		 
		 // Adjusted body weight (ABW):
		 // ABW (kg) = ideal body weight + [0.4 * (actual body weight - ideal body weight)]
		 
		 double adjustedBodyWeight = idealBodyWeight + (0.4d * (weight - idealBodyWeight));
		 double adjustedBWClearanceResult = (140-age) * adjustedBodyWeight / (scr*72);
		 if (!maleSelected) {
			 adjustedBWClearanceResult *= 0.85d;
		 }
		 adjustedBWClearanceResultView.setText("CrCl (ml/min):\t" + Long.toString(Math.round(adjustedBWClearanceResult)));
		 
		 // Actual body weight
		 
		 double totalBWClearanceResult = (140-age) * weight / (scr*72);
		 if (!maleSelected) {
			 totalBWClearanceResult *= 0.85d;
		 }
		 totalBWClearanceResultView.setText("CrCl (ml/min):\t" + Long.toString(Math.round(totalBWClearanceResult)));
		 
		 // Calvert formula for carboplatin dosing
		 // Total Dose (mg) = (target AUC) x (GFR + 25)
		 
		 double idealBWResult = auc*(idealBWClearanceResult+25);
		 double adjustedBWResult = auc*(adjustedBWClearanceResult+25);
		 double totalBWResult = auc*(totalBWClearanceResult+25);
		 
		 idealBWResultView.setText("Carboplatin Dose (mg):\t" + Long.toString(Math.round(idealBWResult)));
		 adjustedBWResultView.setText("Carboplatin Dose (mg):\t" + Long.toString(Math.round(adjustedBWResult)));
		 totalBWResultView.setText("Carboplatin Dose (mg):\t" + Long.toString(Math.round(totalBWResult)));
		 
		 if (btn.getText().equals("Calculate!")) {
			 btn.setText("Go Again!");
			 clrBtn.setVisibility(View.INVISIBLE);
		 }
		 else {
			 btn.setText("Calculate!");
			 clrBtn.setVisibility(View.VISIBLE);
		 }
		 
		 flip.showNext();
		 }
	
	public void ClearInputs(View v) {
		ageText.setText("");
		ageText.setText("");
	    scrText.setText("");
	    heightText.setText("");
	    weightText.setText("");
	    aucText.setText("");
	}

	public class GenderSelectedListener implements OnItemSelectedListener {

		public void onItemSelected(AdapterView<?> parent, View view, int pos,
				long id) {
			if (pos == 0) {
				maleSelected = true;
			} else {
				maleSelected = false;
			}
		}

		@Override
		public void onNothingSelected(AdapterView<?> arg0) {
			// TODO Auto-generated method stub

		}
	}
	
	public class HeightSelectedListener implements OnItemSelectedListener {

		public void onItemSelected(AdapterView<?> parent, View view, int pos,
				long id) {
			if (pos == 0) {
				inchesSelected = true;
			} else {
				inchesSelected = false;
			}
			
			SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
			SharedPreferences.Editor editor = settings.edit();
	      	editor.putBoolean("heightunits", inchesSelected);

	      	editor.commit();
		}

		@Override
		public void onNothingSelected(AdapterView<?> arg0) {
			// TODO Auto-generated method stub

		}
	}
	
	public class WeightSelectedListener implements OnItemSelectedListener {

		public void onItemSelected(AdapterView<?> parent, View view, int pos,
				long id) {
			if (pos == 0) {
				poundsSelected = true;
			} else {
				poundsSelected = false;
			}
			
			SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
			SharedPreferences.Editor editor = settings.edit();
	      	editor.putBoolean("weightunits", poundsSelected);

	      	editor.commit();
		}

		@Override
		public void onNothingSelected(AdapterView<?> arg0) {
			// TODO Auto-generated method stub

		}
	}
}