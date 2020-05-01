---
#### Title: "Feature Definitions"
#### Author: "Meghasyam Tummalacherla"
---
The features used for the analysis are derived from `mhealthtools` [https://github.com/Sage-Bionetworks/mhealthtools/tree/master/R]. 


## Tremor

The features are of the format `<feature>.<domain>.<IMF>.<stat>_<axis>_<sensorType>.<STAT>`

| \<feature\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| cent/mean/mn        | mean/centroid                                                                                      |
| complexity        | sqrt(var(diff(diff(values)*sampling_rate)*sampling_rate) /var(diff(values)*sampling_rate))) |
| dfa         | scaling exponent of the detrended fluctuation analysis                                  |
| energy         | energy (or sum of squares of values)                                  |
| EnergyBandN         | energy in frequency band N                                  |
| ewt.permEnt [1]        |  Permutation Entropy of the energies of signals obtained using Empirical Wavelet Transform   |
| ewt.shannonEnt [1]         |  Permutation Entropy of the energies of signals obtained using Empirical Wavelet Transform   |
| ewt.simpsonEnt [1]         |  Permutation Entropy of the energies of signals obtained using Empirical Wavelet Transform   |
| ewt.renyiEnt [1]         |  Permutation Entropy of the energies of signals obtained using Empirical Wavelet Transform   |
| ewt.tsallisEnt [1]         |  Permutation Entropy of the energies of signals obtained using Empirical Wavelet Transform   |
| IQR         | Inter quantile range                                  |
| kurt/kutosis         | kurtosis                                  |
| md/median        | median                                  |
| mobility     | sqrt(var(diff(values)*sampling_rate)/var(values)) |
| mode | mode, most occuring value |
| mod  | most prominent frequency (max magnitude in frequency spectrum) |
| mtkeo         | mean of result of teager-kaiser energy operator on the given series |
| mx     | max |
| Q25 | 1st Quartile cutoff |
| Q75 | 3rd Quartile cutoff |
| range | Difference between max and min values (max - min) |
| rmsmag | Root mean square magnitude |
| rough [2] | roughness or total curvature  |
| rugo [3] | rugosity |
| sd          | standard deviation                                                                        |
| sem | standard deviation per frequency bin of the spectrum |
| sfm | spectral flatness measure |
| sh | Shannon entropy |
| skew/skewness | skewness |

[1] - https://github.com/Sage-Bionetworks/mhealthtools/blob/master/R/feature_extraction_functions.R#L107

[2] - https://rdrr.io/cran/seewave/man/roughness.html

[3] - https://rdrr.io/cran/seewave/man/rugo.html

| \<domain\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| tm | time|
| fr | frequency (FFT)|

| \<IMF\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| IMFN [4] | Nth Intrinsic Mode Function obtained from Emprirical Mode Decomposition |

[4] - https://www.rdocumentation.org/packages/EMD/versions/1.5.8/topics/emd




| \<stat\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| md | median |
| iqr | interquantile range |

Scope of \<stat\> is at record level. ie., for eg., `skewness.tm.IMF1.md_uav_gyroscope` is obtained 
by taking the median of the feature obtained from `skewnwss, tm, IMF1, uav, gyrscope` across all windows for a given record

| \<axis\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| ua | user linear acceleration (accelerometer) |
| ud | user linear displacement (accelerometer) |
| uv | user linear velocity (accelerometer) |
| uj | user linear jerk (accelerometer) |
| uaacf| autocorrelation function of user acceleration (accelerometer) |
| uad | user rotational displacement (gyroscope) |
| uav | user rotational velocity (gyroscope) |
| uavacf | autocorrelation function of user rotational velocity (gyroscope) |
| uaa | user rotational acceleration (gyroscope) |

`ua` is the gravity corrected raw accelerometer values in `m/s^2`

`uav` is the raw rotational velocity collected in `rad/s` by the gyroscope

| \<sensorType\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| acceleromter | accelerometer |
| gyroscope | gyroscope |

| \<STAT\>      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| md | median |
| iqr | interquantile range |

\<STAT\> is optional. Scope of \<STAT\> is at individual level. ie., for eg., `skewness.tm.IMF1.md_uav_gyroscope.IQR` is obtained 
by taking the inter quantile range across all records for a given subject

## Tapping

