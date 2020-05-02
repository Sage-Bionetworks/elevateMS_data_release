
#### Title: "Feature Definitions"
#### Author: "Meghasyam Tummalacherla"

## Tapping
The following features used were extracted using `mhealthtools` [https://github.com/Sage-Bionetworks/mhealthtools]. 

| Feature Name      | Definition                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| meanTapInter      | mean tapping interval                                                                             |
| medianTapInter    | median tapping interval                                                                           |
| iqrTapInter       | interquartile range tapping interval                                                              |
| minTapInter       | minimum tapping interval                                                                          |
| maxTapInter       | maximum tapping interval                                                                          |
| skewTapInter      | skewness tapping interval                                                                         |
| kurTapInter       | kurtosis tapping interval                                                                         |
| sdTapInter        | standard deviation tapping interval                                                               |
| madTapInter       | mean absolute deviation tapping interval                                                          |
| cvTapInter        | coefficient of variation tapping interval                                                         |
| rangeTapInter     | range tapping interval                                                                            |
| tkeoTapInter      | teager-kaiser energy operator tapping interval                                                    |
| ar1TapInter       | autocorrelation (lag = 1) tapping interval                                                        |
| ar2TapInter       | autocorrelation (lag = 2) tapping interval                                                        |
| fatigue10TapInter | difference in mean tapping interval between the first and last 10% of the tapping interval series |
| fatigue25TapInter | difference in mean tapping interval between the first and last 25% of the tapping interval series |
| fatigue50TapInter | difference in mean tapping interval between the first and last 50% of the tapping interval series |
| meanDriftLeft     | mean drift in the left button                                                                     |
| medianDriftLeft   | median drift in the left button                                                                   |
| iqrDriftLeft      | interquartile range of drift in the left button                                                   |
| minDriftLeft      | minimum of drift in the left button                                                               |
| maxDriftLeft      | maximum of drift in the left button                                                               |
| skewDriftLeft     | skewness of drift in the left button                                                              |
| kurDriftLeft      | kurtosis of drift in the left button                                                              |
| sdDriftLeft       | standard deviation of drift in the left button |
| madDriftLeft      | mean absolute deviation of drift in the left button |
| cvDriftLeft       | coefficient of variation of drift in the left button |
| rangeDriftLeft    | range of drift in the left button |
| meanDriftRight    | mean drift in the right button |
| medianDriftRight  | median drift in the right button |
| iqrDriftRight     | interquartile range of drift in the right button |
| minDriftRight     | minimum of drift in the right button |
| maxDriftRight     | maximum of drift in the right button |
| skewDriftRight    | skewness of drift in the right button |
| kurDriftRight     | kurtosis of drift in the right button |
| sdDriftRight      | standard deviation of drift in the right button |
| madDriftRight     | mean absolute deviation of drift in the right button |
| cvDriftRight      | coefficient of variation of drift in the right button |
| rangeDriftRight   | range of drift in the right button |
| numberTaps         | number of taps |
| buttonNoneFreq    | frequency where neither the left or right buttons were hit |
| corXY             | correlation between the X and Y coordinates of the hits |

## Rest
The following features used were extracted using `mpowertools` [https://github.com/itismeghasyam/mpowertools]. 

| Feature Name | Definition                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------------- |
| meanAA       |  mean of the average acceleration series                                                          |
| sdAA         |  standard deviation of the average acceleration series                                            |
| modeAA       |  mode of the average acceleration series                                                          |
| skewAA       |  skewness of the average acceleration series                                                      |
| kurAA        |  kurtosis of the average acceleration series                                                      |
| q1AA         |  first quartile of the average acceleration series                                                |
| medianAA     |  median of the average acceleration series                                                        |
| q3AA         |  third quartile of the average acceleration series                                                |
| iqrAA        |  interquartile range of the average acceleration series                                           |
| rangeAA      |  range of the average acceleration series                                                         |
| acfAA        |  autocorrelation (lag = 1) of the average acceleration series                                     |
| zcrAA        |  zero-crossing rate of the average acceleration series                                            |
| dfaAA        |  scaling exponent of the detrended fluctuation analysis of the average acceleration series        |
| turningTime  |  turning time                                                                                     |
| Postpeak     |  posture peak                                                                                     |
| Postpower    |  posture power                                                                                    |
| Alpha        |  scaling exponent of the detrended fluctuation analysis of the force vector magnitute series      |
| dVol         | displacement volume (volume of the box around the displacement across the X, Y, and Z directions) |
| ddVol        | delta displacement volume                                                                         |


## Tremor
The following features used were extracted using `mhealthtools` [https://github.com/Sage-Bionetworks/mhealthtools]. 

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
| md        | median                                  |
| median        | median                                  |
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

