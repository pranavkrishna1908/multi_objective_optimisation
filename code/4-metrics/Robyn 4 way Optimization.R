# Copyright (c) Meta Platforms, Inc. and its affiliates.

# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#############################################################################################
####################         Meta MMM Open Source: Robyn 3.11.0       #######################
####################             Quick demo guide                     #######################
#############################################################################################

# Advanced marketing mix modeling using Meta Open Source project Robyn (Blueprint training)
# https://www.facebookblueprint.com/student/path/253121-marketing-mix-models?utm_source=demo

################################################################
#### Step 0: Setup environment

## Install, load, and check (latest) Robyn version, using one of these 2 sources:
## A) Install the latest stable version from CRAN:
# install.packages("Robyn")
## B) Install the latest dev version from GitHub:
# install.packages("remotes") # Install remotes first if you haven't already
remotes::install_github("febpeter/robyn_4d/R", force = TRUE)
library(Robyn)

# Please, check if you have installed the latest version before running this demo. Update if not
# https://github.com/facebookexperimental/Robyn/blob/main/R/DESCRIPTION#L4
#packageVersion("Robyn")
# Also, if you're using an older version than the latest dev version, please check older demo.R with
# https://github.com/facebookexperimental/Robyn/blob/vX.X.X/demo/demo.R

## Force multi-core use when running RStudio
Sys.setenv(R_FUTURE_FORK_ENABLE = "true")
options(future.fork.enable = TRUE)

# Set to FALSE to avoid the creation of files locally
create_files <- TRUE

## IMPORTANT: Must install and setup the python library "Nevergrad" once before using Robyn
## Guide: https://github.com/facebookexperimental/Robyn/blob/main/demo/install_nevergrad.R

################################################################
#### Step 1: Load data

## Check simulated dataset or load your own dataset
data("dt_simulated_weekly")
head(dt_simulated_weekly)

## Check holidays from Prophet
# 59 countries included. If your country is not included, please manually add it.
# Tipp: any events can be added into this table, school break, events etc.
data("dt_prophet_holidays")
head(dt_prophet_holidays)

# Directory where you want to export results to (will create new folders)
robyn_directory <- "D:/Febin/Robyn Pareto Optimization R&D/Pareto Optimization Demo Robyn"

################################################################
#### Step 2a: For first time user: Model specification in 4 steps

#### 2a-1: First, specify input variables

## All sign control are now automatically provided: "positive" for media & organic
## variables and "default" for all others. User can still customise signs if necessary.
## Documentation is available, access it anytime by running: ?robyn_inputs
InputCollect <- robyn_inputs(
  dt_input = dt_simulated_weekly,
  dt_holidays = dt_prophet_holidays,
  date_var = "DATE", # date format must be "2020-01-01"
  dep_var = "revenue", # there should be only one dependent variable
  dep_var_type = "revenue", # "revenue" (ROI) or "conversion" (CPA)
  prophet_vars = c("trend", "season", "holiday"), # "trend","season", "weekday" & "holiday"
  prophet_country = "DE", # input country code. Check: dt_prophet_holidays
  context_vars = c("competitor_sales_B", "events"), # e.g. competitors, discount, unemployment etc
  paid_media_spends = c("tv_S", "ooh_S", "print_S", "facebook_S", "search_S"), # mandatory input
  paid_media_vars = c("tv_S", "ooh_S", "print_S", "facebook_I", "search_clicks_P"), # mandatory.
  # paid_media_vars must have same order as paid_media_spends. Use media exposure metrics like
  # impressions, GRP etc. If not applicable, use spend instead.
  organic_vars = "newsletter", # marketing activity without media spend
  # factor_vars = c("events"), # force variables in context_vars or organic_vars to be categorical
  window_start = "2016-01-01",
  window_end = "2018-12-31",
  adstock = "geometric" # geometric, weibull_cdf or weibull_pdf.
)
print(InputCollect)

#### 2a-2: Second, define and add hyperparameters

## Default media variable for modelling has changed from paid_media_vars to paid_media_spends.
## Also, calibration_input are required to be spend names.
## hyperparameter names are based on paid_media_spends names too. See right hyperparameter names:
hyper_names(adstock = InputCollect$adstock, all_media = InputCollect$all_media)

## Guide to setup & understand hyperparameters

## Robyn's hyperparameters have four components:
## - Adstock parameters (theta or shape/scale)
## - Saturation parameters (alpha/gamma)
## - Regularisation parameter (lambda). No need to specify manually
## - Time series validation parameter (train_size)

## 1. IMPORTANT: set plot = TRUE to create example plots for adstock & saturation
## hyperparameters and their influence in curve transformation.
plot_adstock(plot = FALSE)
plot_saturation(plot = FALSE)

## 2. Get correct hyperparameter names:
# All variables in paid_media_spends and organic_vars require hyperparameter and will be
# transformed by adstock & saturation.
# Run hyper_names(adstock = InputCollect$adstock, all_media = InputCollect$all_media)
# to get correct media hyperparameter names. All names in hyperparameters must equal
# names from hyper_names(), case sensitive. Run ?hyper_names to check function arguments.

## 3. Hyperparameter interpretation & recommendation:

## Geometric adstock: Theta is the only parameter and means fixed decay rate. Assuming TV
# spend on day 1 is 100€ and theta = 0.7, then day 2 has 100*0.7=70€ worth of effect
# carried-over from day 1, day 3 has 70*0.7=49€ from day 2 etc. Rule-of-thumb for common
# media genre: TV c(0.3, 0.8), OOH/Print/Radio c(0.1, 0.4), digital c(0, 0.3). Also,
# to convert weekly to daily we can transform the parameter to the power of (1/7),
# so to convert 30% daily to weekly is 0.3^(1/7) = 0.84.

## Weibull CDF adstock: The Cumulative Distribution Function of Weibull has two parameters,
# shape & scale, and has flexible decay rate, compared to Geometric adstock with fixed
# decay rate. The shape parameter controls the shape of the decay curve. Recommended
# bound is c(0, 2). The larger the shape, the more S-shape. The smaller, the more
# L-shape. Scale controls the inflexion point of the decay curve. We recommend very
# conservative bounce of c(0, 0.1), because scale increases the adstock half-life greatly.
# When shape or scale is 0, adstock will be 0.

## Weibull PDF adstock: The Probability Density Function of the Weibull also has two
# parameters, shape & scale, and also has flexible decay rate as Weibull CDF. The
# difference is that Weibull PDF offers lagged effect. When shape > 2, the curve peaks
# after x = 0 and has NULL slope at x = 0, enabling lagged effect and sharper increase and
# decrease of adstock, while the scale parameter indicates the limit of the relative
# position of the peak at x axis; when 1 < shape < 2, the curve peaks after x = 0 and has
# infinite positive slope at x = 0, enabling lagged effect and slower increase and decrease
# of adstock, while scale has the same effect as above; when shape = 1, the curve peaks at
# x = 0 and reduces to exponential decay, while scale controls the inflexion point; when
# 0 < shape < 1, the curve peaks at x = 0 and has increasing decay, while scale controls
# the inflexion point. When all possible shapes are relevant, we recommend c(0.0001, 10)
# as bounds for shape; when only strong lagged effect is of interest, we recommend
# c(2.0001, 10) as bound for shape. In all cases, we recommend conservative bound of
# c(0, 0.1) for scale. Due to the great flexibility of Weibull PDF, meaning more freedom
# in hyperparameter spaces for Nevergrad to explore, it also requires larger iterations
# to converge. When shape or scale is 0, adstock will be 0.

## Hill function for saturation: Hill function is a two-parametric function in Robyn with
# alpha and gamma. Alpha controls the shape of the curve between exponential and s-shape.
# Recommended bound is c(0.5, 3). The larger the alpha, the more S-shape. The smaller, the
# more C-shape. Gamma controls the inflexion point. Recommended bounce is c(0.3, 1). The
# larger the gamma, the later the inflection point in the response curve.

## Regularization for ridge regression: Lambda is the penalty term for regularised regression.
# Lambda doesn't need manual definition from the users, because it is set to the range of
# c(0, 1) by default in hyperparameters and will be scaled to the proper altitude with
# lambda_max and lambda_min_ratio.

## Time series validation: When ts_validation = TRUE in robyn_run(), train_size defines the
# percentage of data used for training, validation and out-of-sample testing. For example,
# when train_size = 0.7, val_size and test_size will be 0.15 each. This hyperparameter is
# customizable with default range of c(0.5, 0.8) and must be between c(0.1, 1).

## 4. Set individual hyperparameter bounds. They either contain two values e.g. c(0, 0.5),
# or only one value, in which case you'd "fix" that hyperparameter.
# Run hyper_limits() to check maximum upper and lower bounds by range
hyper_limits()

# Example hyperparameters ranges for Geometric adstock
hyperparameters <- list(
  facebook_S_alphas = c(0.5, 3),
  facebook_S_gammas = c(0.3, 1),
  facebook_S_thetas = c(0, 0.3),
  print_S_alphas = c(0.5, 3),
  print_S_gammas = c(0.3, 1),
  print_S_thetas = c(0.1, 0.4),
  tv_S_alphas = c(0.5, 3),
  tv_S_gammas = c(0.3, 1),
  tv_S_thetas = c(0.3, 0.8),
  search_S_alphas = c(0.5, 3),
  search_S_gammas = c(0.3, 1),
  search_S_thetas = c(0, 0.3),
  ooh_S_alphas = c(0.5, 3),
  ooh_S_gammas = c(0.3, 1),
  ooh_S_thetas = c(0.1, 0.4),
  newsletter_alphas = c(0.5, 3),
  newsletter_gammas = c(0.3, 1),
  newsletter_thetas = c(0.1, 0.4),
  train_size = c(0.5, 0.8)
)

# Example hyperparameters ranges for Weibull CDF adstock
# facebook_S_alphas = c(0.5, 3)
# facebook_S_gammas = c(0.3, 1)
# facebook_S_shapes = c(0, 2)
# facebook_S_scales = c(0, 0.1)

# Example hyperparameters ranges for Weibull PDF adstock
# facebook_S_alphas = c(0.5, 3)
# facebook_S_gammas = c(0.3, 1)
# facebook_S_shapes = c(0, 10)
# facebook_S_scales = c(0, 0.1)

#### 2a-3: Third, add hyperparameters into robyn_inputs()

InputCollect <- robyn_inputs(InputCollect = InputCollect, hyperparameters = hyperparameters)
print(InputCollect)

#### 2a-4: Fourth (optional), model calibration / add experimental input

## Guide for calibration

# 1. Calibration channels need to be paid_media_spends or organic_vars names.
# 2. We strongly recommend to use Weibull PDF adstock for more degree of freedom when
# calibrating Robyn.
# 3. We strongly recommend to use experimental and causal results that are considered
# ground truth to calibrate MMM. Usual experiment types are identity-based (e.g. Facebook
# conversion lift) or geo-based (e.g. Facebook GeoLift). Due to the nature of treatment
# and control groups in an experiment, the result is considered immediate effect. It's
# rather impossible to hold off historical carryover effect in an experiment. Therefore,
# only calibrates the immediate and the future carryover effect. When calibrating with
# causal experiments, use calibration_scope = "immediate".
# 4. It's controversial to use attribution/MTA contribution to calibrate MMM. Attribution
# is considered biased towards lower-funnel channels and strongly impacted by signal
# quality. When calibrating with MTA, use calibration_scope = "immediate".
# 5. Every MMM is different. It's highly contextual if two MMMs are comparable or not.
# In case of using other MMM result to calibrate Robyn, use calibration_scope = "total".
# 6. Currently, Robyn only accepts point-estimate as calibration input. For example, if
# 10k$ spend is tested against a hold-out for channel A, then input the incremental
# return as point-estimate as the example below.
# 7. The point-estimate has to always match the spend in the variable. For example, if
# channel A usually has $100K weekly spend and the experimental holdout is 70%, input
# the point-estimate for the $30K, not the $70K.
# 8. If an experiment contains more than one media variable, input "channe_A+channel_B"
# to indicate combination of channels, case sensitive.

# calibration_input <- data.frame(
#   # channel name must in paid_media_vars
#   channel = c("facebook_S",  "tv_S", "facebook_S+search_S", "newsletter"),
#   # liftStartDate must be within input data range
#   liftStartDate = as.Date(c("2018-05-01", "2018-04-03", "2018-07-01", "2017-12-01")),
#   # liftEndDate must be within input data range
#   liftEndDate = as.Date(c("2018-06-10", "2018-06-03", "2018-07-20", "2017-12-31")),
#   # Provided value must be tested on same campaign level in model and same metric as dep_var_type
#   liftAbs = c(400000, 300000, 700000, 200),
#   # Spend within experiment: should match within a 10% error your spend on date range for each channel from dt_input
#   spend = c(421000, 7100, 350000, 0),
#   # Confidence: if frequentist experiment, you may use 1 - pvalue
#   confidence = c(0.85, 0.8, 0.99, 0.95),
#   # KPI measured: must match your dep_var
#   metric = c("revenue", "revenue", "revenue", "revenue"),
#   # Either "immediate" or "total". For experimental inputs like Facebook Lift, "immediate" is recommended.
#   calibration_scope = c("immediate", "immediate", "immediate", "immediate")
# )
# InputCollect <- robyn_inputs(InputCollect = InputCollect, calibration_input = calibration_input)


################################################################
#### Step 2b: For known model specification, setup in one single step

## Specify hyperparameters as in 2a-2 and optionally calibration as in 2a-4 and provide them directly in robyn_inputs()

# InputCollect <- robyn_inputs(
#   dt_input = dt_simulated_weekly
#   ,dt_holidays = dt_prophet_holidays
#   ,date_var = "DATE"
#   ,dep_var = "revenue"
#   ,dep_var_type = "revenue"
#   ,prophet_vars = c("trend", "season", "holiday")
#   ,prophet_country = "DE"
#   ,context_vars = c("competitor_sales_B", "events")
#   ,paid_media_spends = c("tv_S", "ooh_S",	"print_S", "facebook_S", "search_S")
#   ,paid_media_vars = c("tv_S", "ooh_S", 	"print_S", "facebook_I", "search_clicks_P")
#   ,organic_vars = c("newsletter")
#   ,factor_vars = c("events")
#   ,window_start = "2016-11-23"
#   ,window_end = "2018-08-22"
#   ,adstock = "geometric"
#   ,hyperparameters = hyperparameters # as in 2a-2 above
#   ,calibration_input = calibration_input # as in 2a-4 above
# )

#### Check spend exposure fit if available
# if (length(InputCollect$exposure_vars) > 0) {
#   lapply(InputCollect$modNLS$plots, plot)
# }

##### Manually save and import InputCollect as JSON file
# robyn_write(InputCollect, dir = "~/Desktop")
# InputCollect <- robyn_inputs(
#   dt_input = dt_simulated_weekly,
#   dt_holidays = dt_prophet_holidays,
#   json_file = "~/Desktop/RobynModel-inputs.json")

################################################################
#### Step 3: Build initial model

## Run all trials and iterations. Use ?robyn_run to check parameter definition
OutputModels <- robyn_run(
  InputCollect = InputCollect, # feed in all model specification
  cores = 9, # NULL defaults to (max available - 1)
  iterations = 2000, # 2000 recommended for the dummy dataset with no calibration
  trials = 5, # 5 recommended for the dummy dataset
  ts_validation = FALSE, # 3-way-split time series for NRMSE validation.
  add_penalty_factor = FALSE # Experimental feature. Use with caution.
)
print(OutputModels)
library(dplyr)
results1 <- OutputModels$trial1$resultCollect$xDecompAgg %>% select(solID, nrmse, decomp.rssd, MAPE_train, KL_Divergence) %>% unique()
results2 <- OutputModels$trial2$resultCollect$xDecompAgg %>% select(solID, nrmse, decomp.rssd, MAPE_train, KL_Divergence) %>% unique()
results3 <- OutputModels$trial3$resultCollect$xDecompAgg %>% select(solID, nrmse, decomp.rssd, MAPE_train, KL_Divergence) %>% unique()
results4 <- OutputModels$trial4$resultCollect$xDecompAgg %>% select(solID, nrmse, decomp.rssd, MAPE_train, KL_Divergence) %>% unique()
results5 <- OutputModels$trial5$resultCollect$xDecompAgg %>% select(solID, nrmse, decomp.rssd, MAPE_train, KL_Divergence) %>% unique()

results_combined <- rbind(results1, results2, results3, results4, results5)
write.csv(results_combined, "objective_fn_values_4way_kldiv.csv")

## Check MOO (multi-objective optimization) convergence plots
# Read more about convergence rules: ?robyn_converge
OutputModels$convergence$moo_distrb_plot
OutputModels$convergence$moo_cloud_plot

## Check time-series validation plot (when ts_validation == TRUE)
# Read more and replicate results: ?ts_validation
if (OutputModels$ts_validation) OutputModels$ts_validation_plot

## Calculate Pareto fronts, cluster and export results and plots. See ?robyn_outputs
OutputCollect <- robyn_outputs(
  InputCollect, OutputModels,
  pareto_fronts = "auto", # automatically pick how many pareto-fronts to fill min_candidates (100)
  # min_candidates = 100, # top pareto models for clustering. Default to 100
  # calibration_constraint = 0.1, # range c(0.01, 0.1) & default at 0.1
  csv_out = "pareto", # "pareto", "all", or NULL (for none)
  clusters = TRUE, # Set to TRUE to cluster similar models by ROAS. See ?robyn_clusters
  export = create_files, # this will create files locally
  plot_folder = robyn_directory, # path for plots exports and files creation
  plot_pareto = create_files # Set to FALSE to deactivate plotting and saving model one-pagers
)
print(OutputCollect)

## 4 csv files are exported into the folder for further usage. Check schema here:
## https://github.com/facebookexperimental/Robyn/blob/main/demo/schema.R
# pareto_hyperparameters.csv, hyperparameters per Pareto output model
# pareto_aggregated.csv, aggregated decomposition per independent variable of all Pareto output
# pareto_media_transform_matrix.csv, all media transformation vectors
# pareto_alldecomp_matrix.csv, all decomposition vectors of independent variables
