#' Load FU allocation tables
#'
#' This function reads all final-to-useful allocation data
#' in files in the `fu_analysis_folder` that start with the country abbreviations
#' given in `countries`.
#'
#' By default, it is assumed that each country's final-to-useful analysis file will be in a subfolder
#' of `fu_analysis_path`.
#' Set `use_subfolders` to `FALSE` to change the default behavior.
#'
#' If final-to-useful allocation data are not available, this function
#' automatically creates an empty final-to-useful allocation template and writes it to disk.
#' Then, this function reads the empty file.
#' This behavior can be modified by setting argument `generate_missing_fu_allocation_template` to `FALSE`.
#'
#' @param fu_analysis_folder The folder from which final-to-useful analyses will be loaded.
#' @param specified_iea_data A data frame of specified IEA data for `countries`.
#' @param countries The countries for which allocation tables should be loaded.
#' @param file_suffix The suffix for the FU analysis files. Default is "`r IEATools::fu_analysis_file_info$fu_analysis_file_suffix`".
#' @param use_subfolders Tells whether to look for files in subfolders named by `countries`. Default is `TRUE`.
#' @param generate_missing_fu_allocation_template Tells whether to generate a missing final-to-useful allocation template from `specified_iea_data`. Default is `TRUE`.
#' @param fu_allocations_tab_name The name of the tab for final-to-useful allocations in the Excel file containing final-to-useful allocation data. Default is "`r IEATools::fu_analysis_file_info$fu_allocation_tab_name`".
#'
#' @export
#'
#' @return A data frame of FU Allocation tables read by `IEATools::load_fu_allocation_data()`.
#'         If no FU Allocation data are found and `generate_missing_fu_allocation_template` is `TRUE`,
#'         an empty template written to disk and the empty template is returned.
#'         If no FU Allocation data are found and `generate_missing_fu_allocation_template` is `FALSE`,
#'         `NULL` is returned.
load_fu_allocation_tables <- function(fu_analysis_folder,
                                      specified_iea_data,
                                      countries,
                                      file_suffix = IEATools::fu_analysis_file_info$fu_analysis_file_suffix,
                                      use_subfolders = TRUE,
                                      generate_missing_fu_allocation_template = TRUE,
                                      fu_allocations_tab_name = IEATools::fu_analysis_file_info$fu_allocation_tab_name) {
  out <- lapply(countries, FUN = function(coun) {
    folder <- ifelse(use_subfolders, file.path(fu_analysis_folder, coun), fu_analysis_folder)
    fpath <- file.path(folder, paste0(coun, file_suffix))
    fexists <- file.exists(fpath)
    if (!fexists & !generate_missing_fu_allocation_template) {
      return(NULL)
    }
    if (!fexists & generate_missing_fu_allocation_template) {
      # Make sure we have the folder we need
      dir.create(folder, showWarnings = FALSE)
      # Create and write the template
      iea_data <- specified_iea_data %>%
        dplyr::filter(.data[[IEATools::iea_cols$country]] == coun)
      IEATools::fu_allocation_template(iea_data) %>%
        IEATools::write_fu_allocation_template(fpath)
    }
    # Read the FU allocation data from fpath.
    IEATools::load_fu_allocation_data(fpath, fu_allocations_tab_name = fu_allocations_tab_name)
  }) %>%
    dplyr::bind_rows()
  if (nrow(out) == 0) {
    return(NULL)
  }
  return(out)
}


#' Load FU efficiency tables
#'
#' This function reads all final-to-useful efficiency data
#' in files in the `fu_analysis_folder` that start with the country prefixes
#' given in `countries`.
#'
#' By default, it is assumed that each country's final-to-useful analysis file will be in a subfolder
#' of `fu_analysis_path`.
#' Set `use_subfolders` to `FALSE` to change the default behavior.
#'
#' If the file from which final-to-useful efficiencies are to be read
#' does not exist, an error is thrown.
#'
#' If the file from which final-to-useful efficiencies are to be read exists
#' but no tab named `eta_fu_tab_name` exists,
#' a blank template will be generated and saved into the file.
#'
#' @param fu_analysis_folder The folder from which final-to-useful analyses will be loaded.
#' @param completed_fu_allocation_tables A data frame of completed final-to-useful allocation tables
#'                                       for `countries` used to generate an FU efficiency template
#'                                       on the fly, if needed and if
#'                                       `generate_missing_fu_etas_template` is `TRUE`.
#' @param tidy_specified_iea_data A data frame of tidy and specified IEA data
#'                                that are used to make a blank eta_fu template,
#'                                if needed.
#'                                Note that this argument needs to be specified only
#'                                when the eta_fu template is unavailable.
#' @param countries The countries for which allocation tables should be loaded.
#' @param file_suffix The suffix for the FU analysis files. Default is "`r IEATools::fu_analysis_file_info$fu_analysis_file_suffix`".
#' @param use_subfolders Tells whether to look for files in subfolders named by `countries`. Default is `TRUE`.
#' @param generate_missing_fu_etas_template Tells whether to create a template for final-to-useful efficiencies. Default is `TRUE`.
#' @param eta_fu_tab_name See `IEATools::fu_analysis_file_info`.
#'
#' @export
#'
#' @return A data frame of FU efficiency tables read by `IEATools::load_eta_fu_data()`.
#'         If no FU Efficiency data are found and `generate_missing_fu_etas_template` is `TRUE`,
#'         an empty template written to disk and the empty template is returned.
#'         If no FU Efficiency data are found and `generate_missing_fu_etas_template` is `FALSE`,
#'         `NULL` is returned.
load_eta_fu_tables <- function(fu_analysis_folder,
                               completed_fu_allocation_tables,
                               tidy_specified_iea_data,
                               countries,
                               file_suffix = IEATools::fu_analysis_file_info$fu_analysis_file_suffix,
                               use_subfolders = TRUE,
                               generate_missing_fu_etas_template = TRUE,
                               eta_fu_tab_name = IEATools::fu_analysis_file_info$eta_fu_tab_name) {
  out <- lapply(countries, FUN = function(coun) {
    folder <- ifelse(use_subfolders, file.path(fu_analysis_folder, coun), fu_analysis_folder)
    fpath <- file.path(folder, paste0(coun, file_suffix))
    fexists <- file.exists(fpath)
    assertthat::assert_that(fexists, msg = paste0("Trying to read final-to-useful efficiency data from file ", fpath, ", which does not exist."))

    # Check if the tab exists
    tab_exists <- eta_fu_tab_name %in% readxl::excel_sheets(fpath)

    if (!tab_exists & !generate_missing_fu_etas_template) {
      return(NULL)
    }

    if (!tab_exists & generate_missing_fu_etas_template) {
      relevant_iea_data <- tidy_specified_iea_data %>%
        dplyr::filter(.data[[IEATools::iea_cols$country]] == coun)
      relevant_fu_allocation_table <- completed_fu_allocation_tables %>%
        dplyr::filter(.data[[IEATools::iea_cols$country]] == coun)
      # Try to make the eta_fu template and stuff it in the file.
      IEATools::eta_fu_template(relevant_fu_allocation_table,
                                tidy_specified_iea_data = relevant_iea_data) %>%
        IEATools::write_eta_fu_template(eta_fu_tab_name = eta_fu_tab_name, path = fpath, overwrite_file = TRUE, overwrite_fu_eta_tab = TRUE)
    }

    # Whether an eta_fu tab was present at the beginning
    # or we wrote an empty template just now,
    # read it back in.
    IEATools::load_eta_fu_data(fpath, eta_fu_tab_name = eta_fu_tab_name)
  }) %>%
    dplyr::bind_rows()
  if (nrow(out) == 0) {
    return(NULL)
  }
  return(out)
}


#' Assemble completed final-to-useful allocation tables
#'
#' This function is used in a drake workflow to assemble completed final-to-useful allocation tables
#' given a set of incomplete allocation tables.
#'
#' Note that this function can accept tidy or wide by year data frames.
#' The return value is a tidy data frame.
#' Information from exemplar countries is used to complete incomplete final-to-useful efficiency tables.
#' See examples for how to construct `exemplar_lists`.
#'
#' @param incomplete_allocation_tables A data frame containing (potentially) incomplete final-to-useful allocation tables.
#'                                     This data frame may be tidy or wide by years.
#' @param exemplar_lists A data frame containing `country` and `year` columns along with a column of ordered vectors of strings
#'                       telling which countries should be considered exemplars for the country and year of this row.
#' @param specified_iea_data A data frame containing specified IEA data.
#' @param countries A vector of countries for which completed final-to-useful allocation tables are to be assembled.
#' @param max_year The latest year for which analysis is desired. Default is `NULL`, meaning analyze all years.
#' @param country,year See `IEATools::iea_cols`.
#' @param exemplars,exemplar_tables,iea_data,incomplete_alloc_tables,complete_alloc_tables
#'                    See `SEAPSUTWorkflows::exemplar_names`.
#'
#' @return A tidy data frame containing completed final-to-useful allocation tables.
#'
#' @export
#'
#' @examples
#' # Load final-to-useful allocation tables, but eliminate one category of consumption,
#' # Residential consumption of Primary solid biofuels,
#' # which will be filled by the exemplar for GHA, ZAF.
#' incomplete_fu_allocation_tables <- IEATools::load_fu_allocation_data() %>%
#'   dplyr::filter(! (Country == "GHA" & Ef.product == "Primary solid biofuels" &
#'     Destination == "Residential"))
#' # Show that those rows are gone.
#' incomplete_fu_allocation_tables %>%
#'   dplyr::filter(Country == "GHA" & Ef.product == "Primary solid biofuels" &
#'     Destination == "Residential")
#' # But the missing rows of GHA are present in allocation data for ZAF.
#' incomplete_fu_allocation_tables %>%
#'   dplyr::filter(Country == "ZAF" & Ef.product == "Primary solid biofuels" &
#'     Destination == "Residential")
#' # Set up exemplar list
#' el <- tibble::tribble(
#'   ~Country, ~Year, ~Exemplars,
#'   "GHA", 1971, c("ZAF"),
#'   "GHA", 2000, c("ZAF"))
#' el
#' # Load IEA data
#' iea_data <- IEATools::load_tidy_iea_df() %>%
#'   IEATools::specify_all()
#' # Assemble complete allocation tables
#' completed <- assemble_fu_allocation_tables(incomplete_allocation_tables =
#'                                              incomplete_fu_allocation_tables,
#'                                            exemplar_lists = el,
#'                                            specified_iea_data = iea_data,
#'                                            countries = "GHA")
#' # Missing data for GHA has been picked up from ZAF.
#' completed %>%
#'   dplyr::filter(Country == "GHA" & Ef.product == "Primary solid biofuels" &
#'     Destination == "Residential")
assemble_fu_allocation_tables <- function(incomplete_allocation_tables,
                                          exemplar_lists,
                                          specified_iea_data,
                                          countries,
                                          max_year = NULL,
                                          country = IEATools::iea_cols$country,
                                          year = IEATools::iea_cols$year,
                                          exemplars = SEAPSUTWorkflow::exemplar_names$exemplars,
                                          exemplar_tables = SEAPSUTWorkflow::exemplar_names$exemplar_tables,
                                          iea_data = SEAPSUTWorkflow::exemplar_names$iea_data,
                                          incomplete_alloc_tables = SEAPSUTWorkflow::exemplar_names$incomplete_alloc_table,
                                          complete_alloc_tables = SEAPSUTWorkflow::exemplar_names$complete_alloc_table) {

  # The incomplete tables are easier to deal with when they are tidy.
  tidy_incomplete_allocation_tables <- IEATools::tidy_fu_allocation_table(incomplete_allocation_tables)
  if (!is.null(max_year)) {
    tidy_incomplete_allocation_tables <- tidy_incomplete_allocation_tables %>%
      dplyr::filter(.data[[year]] <= max_year)
  }

  completed_tables_by_year <- lapply(countries, FUN = function(coun) {
    coun_exemplar_strings <- exemplar_lists %>%
      dplyr::filter(.data[[country]] == coun)

    # For each combination of Country and Year (the rows of coun_exemplar_strings),
    # assemble a list of country allocation tables.
    coun_exemplar_strings_and_tables <- coun_exemplar_strings %>%
      dplyr::mutate(
        # Create a list column containing lists of exemplar tables
        # corresponding to the countries in the Exemplars column.
        "{exemplar_tables}" := Map(get_one_exemplar_table_list,
                                   # Need to wrap this in a list so the WHOLE table is sent via Map to get_one_exemplar_table_list
                                   tidy_incomplete_tables = list(tidy_incomplete_allocation_tables),
                                   exemplar_strings = .data[[exemplars]],
                                   yr = .data[[year]],
                                   country_colname = country,
                                   year_colname = year),
        # Add a column containing an IEA data frame for the country and year of each row
        "{iea_data}" := Map(get_one_df_by_coun_and_yr,
                            .df = list(specified_iea_data),
                            coun = .data[[country]],
                            yr = .data[[year]],
                            country_colname = country,
                            year_colname = year),
        # Add a column containing incomplete fu allocation tables for each row (i.e., for each combination of country and year).
        "{incomplete_alloc_tables}" := Map(get_one_df_by_coun_and_yr,
                                           .df = list(tidy_incomplete_allocation_tables),
                                           coun = .data[[country]],
                                           yr = .data[[year]],
                                           country_colname = country,
                                           year_colname = year),
        # Add a column containing completed fu allocation tables for each row (i.e., for each combination of country and year).
        # Note that the data frames in this column contain the SOURCE of information for each allocation.
        "{complete_alloc_tables}" := Map(IEATools::complete_fu_allocation_table,
                                         fu_allocation_table = .data[[incomplete_alloc_tables]],
                                         country_to_complete = coun,
                                         exemplar_fu_allocation_tables = .data[[exemplar_tables]],
                                         tidy_specified_iea_data = .data[[iea_data]])
      )
  }) %>%
    dplyr::bind_rows()

  # The only information we need to return is the completed allocation tables.
  # Expand (unnest) only the completed allocation table column to give one data frame of all the FU allocations
  # for all years and all countries.
  completed_tables_by_year %>%
    dplyr::select(complete_alloc_tables) %>%
    tidyr::unnest(cols = .data[[complete_alloc_tables]])
}


#' Assemble completed final-to-useful efficiency tables
#'
#' This function is used in a drake workflow to assemble completed final-to-useful efficiency tables
#' given a set of incomplete efficiency tables.
#' Information from exemplar countries is used to complete incomplete final-to-useful efficiency tables.
#' See examples for how to construct `exemplar_lists`.
#'
#' Note that this function can accept tidy or wide by year data frames.
#' The return value is a tidy data frame.
#'
#' Note that the `.values` argument applies for both
#' `incomplete_eta_fu_tables` and
#' `completed_fu_allocation_tables`.
#' Callers should ensure that value columns in both
#' data frames (`incomplete_eta_fu_tables` and `completed_fu_allocation_tables`)
#' are named identically and that name is passed into the
#' `.values` argument.
#'
#' @param incomplete_eta_fu_tables An incomplete data frame of final-to-useful efficiencies for all Machines in `completed_fu_allocation_tables`.
#' @param exemplar_lists A data frame containing `country` and `year` columns along with a column of ordered vectors of strings
#'                       telling which countries should be considered exemplars for the country and year of this row.
#' @param completed_fu_allocation_tables A data frame containing completed final-to-useful allocation data,
#'                                       typically the result of calling `assemble_fu_allocation_tables`.
#' @param countries A vector of countries for which completed final-to-useful allocation tables are to be assembled.
#' @param max_year The latest year for which analysis is desired. Default is `NULL`, meaning analyze all years.
#' @param which_quantity A vector of quantities to be completed in the eta_FU table.
#'                       Default is `c(IEATools::template_cols$eta_fu, IEATools::template_cols$phi_u)`.
#'                       Must be one or both of the default values.
#' @param country,method,energy_type,last_stage,year,unit,e_dot See `IEATools::iea_cols`.
#' @param machine,eu_product,eta_fu,phi_u,c_source,eta_fu_phi_u_source,e_dot_machine,e_dot_machine_perc,quantity,maximum_values,e_dot_perc,.values See `IEATools::template_cols`.
#' @param exemplars,exemplar_tables,alloc_data,incomplete_eta_tables,complete_eta_tables See `SEAPSUTWorkflows::exemplar_names`.
#'
#' @return A tidy data frame containing completed final-to-useful efficiency tables.
#'
#' @export
#'
#' @examples
#' # Make some incomplete efficiency tables for GHA by removing Wood cookstoves.
#' # Information from the exemplar, ZAF, will supply efficiency for Wood cookstoves for GHA.
#' incomplete_eta_fu_tables <- IEATools::load_eta_fu_data() %>%
#'   dplyr::filter(! (Country == "GHA" & Machine == "Wood cookstoves"))
#' # The rows for Wood cookstoves are missing.
#' incomplete_eta_fu_tables %>%
#'   dplyr::filter(Country == "GHA", Machine == "Wood cookstoves")
#' # Set up exemplar list
#' el <- tibble::tribble(
#'   ~Country, ~Year, ~Exemplars,
#'   "GHA", 1971, c("ZAF"),
#'   "GHA", 2000, c("ZAF"))
#' # Load FU allocation data.
#' # An efficiency is needed for each machine in FU allocation data.
#' fu_allocation_data <- IEATools::load_fu_allocation_data()
#' # Assemble complete allocation tables
#' completed <- assemble_eta_fu_tables(incomplete_eta_fu_tables = incomplete_eta_fu_tables,
#'                                     exemplar_lists = el,
#'                                     completed_fu_allocation_tables = fu_allocation_data,
#'                                     countries = "GHA")
#' # Show that the missing rows have been picked up from the exemplar country, ZAF.
#' completed %>%
#'   dplyr::filter(Country == "GHA", Machine == "Wood cookstoves")
assemble_eta_fu_tables <- function(incomplete_eta_fu_tables,
                                   exemplar_lists,
                                   completed_fu_allocation_tables,
                                   countries,
                                   max_year = NULL,
                                   which_quantity = c(IEATools::template_cols$eta_fu, IEATools::template_cols$phi_u),
                                   country = IEATools::iea_cols$country,
                                   method = IEATools::iea_cols$method,
                                   energy_type = IEATools::iea_cols$energy_type,
                                   last_stage = IEATools::iea_cols$last_stage,
                                   unit = IEATools::iea_cols$unit,
                                   year = IEATools::iea_cols$year,
                                   e_dot = IEATools::iea_cols$e_dot,

                                   machine = IEATools::template_cols$machine,
                                   eu_product = IEATools::template_cols$eu_product,
                                   eta_fu = IEATools::template_cols$eta_fu,
                                   phi_u = IEATools::template_cols$phi_u,
                                   c_source = IEATools::template_cols$c_source,
                                   eta_fu_phi_u_source = IEATools::template_cols$eta_fu_phi_u_source,
                                   e_dot_machine = IEATools::template_cols$e_dot_machine,
                                   e_dot_machine_perc = IEATools::template_cols$e_dot_machine_perc,
                                   quantity = IEATools::template_cols$quantity,
                                   maximum_values = IEATools::template_cols$maximum_values,
                                   e_dot_perc = IEATools::template_cols$e_dot_perc,

                                   exemplars = SEAPSUTWorkflow::exemplar_names$exemplars,
                                   exemplar_tables = SEAPSUTWorkflow::exemplar_names$exemplar_tables,
                                   alloc_data = SEAPSUTWorkflow::exemplar_names$alloc_data,
                                   incomplete_eta_tables = SEAPSUTWorkflow::exemplar_names$incomplete_eta_table,
                                   complete_eta_tables = SEAPSUTWorkflow::exemplar_names$complete_eta_table,

                                   .values = IEATools::template_cols$.values) {

  which_quantity <- match.arg(which_quantity, several.ok = TRUE)

  # The FU allocation tables and the incomplete efficiency tables are easier to deal with when they are tidy.
  tidy_incomplete_eta_fu_tables <- IEATools::tidy_eta_fu_table(incomplete_eta_fu_tables,
                                                               year = year,
                                                               e_dot_machine = e_dot_machine,
                                                               e_dot_machine_perc = e_dot_machine_perc,
                                                               quantity = quantity,
                                                               maximum_values = maximum_values,
                                                               .values = .values)
  tidy_allocation_tables <- IEATools::tidy_fu_allocation_table(completed_fu_allocation_tables,
                                                               year = year,
                                                               e_dot = e_dot,
                                                               e_dot_perc = e_dot_perc,
                                                               quantity = quantity,
                                                               maximum_values = maximum_values,
                                                               .values = .values)
  if (!is.null(max_year)) {
    tidy_incomplete_eta_fu_tables <- tidy_incomplete_eta_fu_tables %>%
      dplyr::filter(.data[[year]] <= max_year)
    tidy_allocation_tables <- tidy_allocation_tables %>%
      dplyr::filter(.data[[year]] <= max_year)
  }

  completed_tables_by_year <- lapply(countries, FUN = function(coun) {
    coun_exemplar_strings <- exemplar_lists %>%
      dplyr::filter(.data[[country]] == coun)

    # For each combination of Country and Year (the rows of coun_exemplar_strings),
    # assemble a list of country allocation tables.
    coun_exemplar_strings_and_tables <- coun_exemplar_strings %>%
      dplyr::mutate(
        # Create a list column containing lists of exemplar tables
        # corresponding to the countries in the Exemplars column.
        "{exemplar_tables}" := Map(get_one_exemplar_table_list,
                                   # Need to wrap this in a list so the WHOLE table is sent via Map to get_one_exemplar_table_list
                                   tidy_incomplete_tables = list(tidy_incomplete_eta_fu_tables),
                                   exemplar_strings = .data[[exemplars]],
                                   yr = .data[[year]],
                                   country_colname = country,
                                   year_colname = year),
        # Add a column containing an FU allocation data frame for the country and year of each row
        "{alloc_data}" := Map(get_one_df_by_coun_and_yr,
                              .df = list(tidy_allocation_tables),
                              coun = .data[[country]],
                              yr = .data[[year]],
                              country_colname = country,
                              year_colname = year),
        # Add a column containing incomplete fu eta tables for each row (i.e., for each combination of country and year).
        "{incomplete_eta_tables}" := Map(get_one_df_by_coun_and_yr,
                                         .df = list(tidy_incomplete_eta_fu_tables),
                                         coun = .data[[country]],
                                         yr = .data[[year]],
                                         country_colname = country,
                                         year_colname = year),
        # Add a column containing completed fu efficiency tables for each row (i.e., for each combination of country and year).
        # Note that the data frames in this column contain the SOURCE of information for each efficiency
        "{complete_eta_tables}" := Map(IEATools::complete_eta_fu_table,
                                       eta_fu_table = .data[[incomplete_eta_tables]],
                                       exemplar_eta_fu_tables = .data[[exemplar_tables]],
                                       fu_allocation_table = .data[[alloc_data]],
                                       which_quantity = list(which_quantity),

                                       country = country,
                                       method = method,
                                       energy_type = energy_type,
                                       last_stage = last_stage,
                                       e_dot = e_dot,
                                       unit = unit,
                                       year = year,
                                       machine = machine,
                                       eu_product = eu_product,
                                       e_dot_perc = e_dot_perc,
                                       e_dot_machine = e_dot_machine,
                                       e_dot_machine_perc = e_dot_machine_perc,
                                       eta_fu = eta_fu,
                                       phi_u = phi_u,
                                       quantity = quantity,
                                       maximum_values = maximum_values,
                                       c_source = c_source,
                                       eta_fu_phi_u_source = eta_fu_phi_u_source,
                                       .values = .values)
      )
  }) %>%
    dplyr::bind_rows()

  # The only information we need to return is the completed efficiency tables.
  # Expand (un-nest) only the completed efficiency table column to give one data frame of all the FU efficiencies
  # for all years and all countries.
  completed_tables_by_year %>%
    dplyr::select(complete_eta_tables) %>%
    tidyr::unnest(cols = .data[[complete_eta_tables]])
}


get_one_exemplar_table_list <- function(tidy_incomplete_tables,
                                        exemplar_strings, yr, country_colname, year_colname) {
  lapply(exemplar_strings, function(exemplar_coun) {
    tidy_incomplete_tables %>%
      dplyr::filter(.data[[country_colname]] == exemplar_coun, .data[[year_colname]] == yr)
  })
}


get_one_df_by_coun_and_yr <- function(.df, coun, yr, country_colname, year_colname) {
  .df %>%
    dplyr::filter(.data[[country_colname]] %in% coun, .data[[year_colname]] %in% yr)
}


