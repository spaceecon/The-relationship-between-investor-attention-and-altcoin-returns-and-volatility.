clear
cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price"

// Install Stata package for saving regressions
ssc install outreg2

local files : dir . files "*" //Make a list of all the crypto coins in folder.

local first 1 //For either creating or adding to the panel file

// Loop over the list of crypto coins and add them to a primary 'panel' data file. 
foreach file of local files {
	display "`file'"
	// Remove the file extention to get the coin number and coin.
	local coin = substr("`file'", 1, length("`file'") - 4)
	// Get the coin number/ID
	local coin_id = substr("`coin'", 1, 2)
	local coin_id = real("`coin_id'")
	
	// Prepare the Price data
	import delimited "`file'", delimiter(",")
	gen double date_dbl = date(date, "YMD")
	format date_dbl %d
	gen coin = "`coin'"
	gen coin_id = "`coin_id'"
	cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price-processed"
	save "`coin'", replace
	clear
	
	// Prepare Searches data
	cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Trends 2"
	import delimited "`file'", delimiter(",")
	drop if v1 == "Category: All categories"
	drop if v1 == "Week"
	rename v1 date
	rename v2 Searches
	gen double date_dbl = date(date, "YMD")
	format date_dbl %d
	cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Trends-processed"
	save "`coin'", replace
	
	// Merge Price and Searches data
	cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price-processed"
	merge 1:1 date_dbl using "`coin'", keep(match master) nogenerate
	cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price-Searches"
	save "`coin'", replace
	
	// Either create the panel data or add the new coin data to it.
	  if "`first'" == "1" {
	    // Create panel data.
        save "panel.dta", replace 
    }
    else {
        // Add to panel data.
		clear
		use "panel.dta"
		append using "`coin'"
		save "panel.dta", replace
    }
	
	// Go back to the price directory to add the next coin.
	cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price"
	clear
	local first 0
}

// Open the panel data.
cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price-Searches"
use panel

// Slight cleanup.
destring coin_id, replace
// Some Google Trends data is recorded as <1 in a string, this is replaced by 0
replace Searches = "0" if Searches == "<1" 
destring Searches, replace

// Set that it is a panel.
sort coin_id date_dbl
xtset coin_id date_dbl, delta(7)
sort coin_id date_dbl

// Do the panel calculations for delta GSV, returns, and volatility.
gen ΔGSV = Searches - L1.Searches
gen returns = ln(close) - ln(L1.close)
gen volatility = abs(returns)
save panel, replace


// Clean up control variable data.
clear
cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Control"

//VIX (Uncertainty in general financial markets)
import delimited "^VIX.csv", delimiter(",")
drop v2 v3 v4 v6 v7 // Drop unneeded columns
rename v1 date
rename v5 close 
// Only keep the closing values.
drop if date == "Date" 
// Drop the observation if the value is null.
drop if close == "null"
destring close, replace
// Make the date into a STATA date format.
gen double date_dbl = date(date, "YMD") 
format date_dbl %d
// As the VIX data is only for weekdays, but the search data is for every sunday of the week, the last value of VIX for a friday needs to be used. (The closing value of friday for the week)
// Associates a number with every day of the week. 1=monday, 5=friday.
gen day_of_week = dow(date_dbl) 
// Only keeps the friday data. 
drop if day_of_week < 5 
// Generates the date for the sunday following each friday.
gen date_sunday = date_dbl + 2
format date_sunday %td
// No loger needed.
drop day_of_week date 
rename date_dbl date_VIX_last_friday
// For matching to the panel data purposes. 
rename date_sunday date_dbl 
// Set delta of time so that it is possible to calculate the delta_VIX.
tsset date_dbl, delta(7)
// Lag of 1 (L1) becuase weekly search data. (Every sunday is seperated by a week)
gen ΔVIX = ln(close) - ln(L1.close)
rename close VIX
save vix, replace
clear

//EPU_US (Uncertainty for economic policy)
import excel "EPU US daily.xls", sheet("FRED Graph")
rename A date
rename B EPU_US
drop if date == "FRED Graph Observations"
drop if date == ""
drop if date == "Federal Reserve Economic Data"
drop if date == "Link: https://fred.stlouisfed.org"
drop if date == "Help: https://fredhelp.stlouisfed.org"
drop if date == "Economic Research Division"
drop if date == "Federal Reserve Bank of St. Louis"
drop if date == "USEPUINDXD"
drop if date == "Frequency: Daily, 7-Day"
drop if date == "observation_date"
destring EPU_US, replace
// Make the date into a STATA date format.
gen double date_dbl = date(date, "DMY") 
format date_dbl %d
// Set delta of time so that it is possible to calculate the delta_EPU.
tsset date_dbl, delta(1)
// Lag of 7 (L7) becuase of weekly search data.
gen ΔEPU_US = ln(EPU_US) - ln(L7.EPU_US)
drop date
save epu_us, replace
clear

// ADS (Aruoba-Diebold-Scotti Business Conditions Index)
import excel "ADS_Index_Most_Current_Vintage from Federal Reserve Bank Philidepia.xlsx", sheet("Sheet1")
rename A date
rename B ADS
drop if date == "" 
// Make the date into a STATA date format.
gen double date_dbl = date(date, "YMD") 
format date_dbl %d
destring ADS, replace
// Set delta of time so that it is possible to calculate the delta_ABS.
tsset date_dbl, delta(1)
// Lag of 7 (L7) becuase of weekly search data.
gen ΔADS = ADS - L7.ADS
drop date
save ads, replace 
clear

// TERM (Term premium between 2-year and 10-year Treasury yields)
import excel "TERM-T10Y2Y.xls", sheet("FRED Graph")
rename A date
rename B TERM_T10Y2Y
drop if date == "FRED Graph Observations"
drop if date == ""
drop if date == "Federal Reserve Economic Data"
drop if date == "Link: https://fred.stlouisfed.org"
drop if date == "Help: https://fredhelp.stlouisfed.org"
drop if date == "Economic Research Division"
drop if date == "Federal Reserve Bank of St. Louis"
drop if date == "T10Y2Y"
drop if date == "Frequency: Daily"
drop if date == "observation_date"
// Make the date into a STATA date format.
gen double date_dbl = date(date, "DMY") 
format date_dbl %d
destring TERM_T10Y2Y, replace
// As the TERM data is only for weekdays, but the search data is for every sunday of the week, the last value of TERM for a friday needs to be used. (The closing value of friday for the week) The same as was done for VIX.
// Associates a number with every day of the week. 1=monday, 5=friday. 
gen day_of_week = dow(date_dbl) 
// Only keeps the friday data. 
drop if day_of_week < 5 
// Generates the date for the sunday following each friday.
gen date_sunday = date_dbl + 2
format date_sunday %td
// No loger needed.
drop day_of_week date 
rename date_dbl date_TERM_last_friday
// For matching to the panel data purposes. 
rename date_sunday date_dbl 
// Set delta of time so that it is possible to calculate the delta_VIX.
tsset date_dbl, delta(7)
// Lag of 1 (L1) becuase weekly search data. (Every sunday is seperated by a week)
gen ΔTERM = TERM_T10Y2Y - L1.TERM_T10Y2Y
save term, replace
clear

// Add control variables via m:1 to main panel data. 
cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Price-Searches"
use panel
cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Control"
merge m:1 date_dbl using "vix.dta", force
drop _merge
merge m:1 date_dbl using "epu_us.dta", force
drop _merge
merge m:1 date_dbl using "ads.dta", force
drop _merge
merge m:1 date_dbl using "term.dta", force
drop _merge

drop if coin == ""
save panel, replace


// Summary Statisics
cd "C:\Users\krist\Documents\University\UvA\Semester 6\Thesis\Data\loop\Outputs"
// P5
summarize returns volatility ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM if coin_id < 7
// P25
summarize returns volatility ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM if coin_id < 27
//P50
summarize returns volatility ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM

// Correlations
pwcorr ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM

// Run the panel regressions 
sort coin_id date_dbl

// Panel of 5 highest market-cap altcoins

//Univariate
xtreg returns ΔGSV if inlist(coin_id, 2,3,4,5,6)
// Creating a table to save the univariate regressions for returns
outreg2 using uni_returns, word replace ctitle(P5)
xtreg volatility ΔGSV if inlist(coin_id, 2,3,4,5,6)
// Creating a table to save the univariate regressions for volatility
outreg2 using uni_volatility, word replace ctitle(P5)

// Full
xtreg returns ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM L1.returns if inlist(coin_id, 2,3,4,5,6)
outreg2 using returns, word replace ctitle(P5)
xtreg volatility ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM L1.volatility if inlist(coin_id, 2,3,4,5,6)
outreg2 using volatility, word replace ctitle(P5)
 
// Panel of 25 highest market-cap altcoins
//Univariate
xtreg returns ΔGSV if inlist(coin_id, 2, 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26)
outreg2 using uni_returns, word append ctitle(P25)
xtreg volatility ΔGSV if inlist(coin_id, 2, 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26)
outreg2 using uni_volatility, word append ctitle(P25)

// Full
xtreg returns ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM L1.returns if inlist(coin_id, 2, 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26)
outreg2 using returns, word append ctitle(P25)
xtreg volatility ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM L1.volatility if inlist(coin_id, 2, 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26)
outreg2 using volatility, word append ctitle(P25)

// Panel of 50 highest market-cap altcoins
//Univariate
xtreg returns ΔGSV 
outreg2 using uni_returns, word append ctitle(P50)
xtreg volatility ΔGSV 
outreg2 using uni_volatility, word append ctitle(P50)
// Full
xtreg returns ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM L1.returns
outreg2 using returns, word append ctitle(P50)
xtreg volatility ΔGSV ΔVIX ΔEPU_US ΔADS ΔTERM L1.volatility
outreg2 using volatility, word append ctitle(P50)


