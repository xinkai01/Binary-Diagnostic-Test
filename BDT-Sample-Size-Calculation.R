
# The following R code are based on:
# Pepe, Margaret Sullivan. The statistical evaluation of medical tests for classification and prediction. Medicine, 2003.


ComputeCR.BDT <- function(tp, fp, fn, tn, conf.level = 0.95, 
                          one.sided = T, plot.it = T){
  # Plot the confidence region for "sensitivity" and "1- specificity" 
  # of the Binary Diagnostic Test (BDT)
  #
  # Args: tp: true positives
  #       fp: false positives
  #       fn: false negatives
  #       tn: true negatives
  #       conf.level: confidence level for the join confidence region
  #       plot.it: logical, plot cr or not?
  #
  # Returns: a list with elements:
  #          cr: a dataframe containing point estimates and confidence region
  #          cr.plot: confidence region plot (available when plot.it == T)
  #
  # Xinkai Zhou @UCLA DOMStat
  
  library(ggplot2)
  if(one.sided){
    tpf.ci <- 
      binom.test(x = tp, n = tp + fn, alternative = "greater", 
                         conf.level = sqrt(conf.level))$conf.int[1:2]
    fpf.ci <- 
      binom.test(x = fp, n = fp + tn, alternative = "less", 
                         conf.level = sqrt(conf.level))$conf.int[1:2]
  } else {
    tpf.ci <- 
      binom.test(x = tp, n = tp + fn, alternative = "two.sided", 
                         conf.level = sqrt(conf.level))$conf.int[1:2]
    fpf.ci <- 
      binom.test(x = fp, n = fp + tn, alternative = "two.sided", 
                         conf.level = sqrt(conf.level))$conf.int[1:2]
  }

  # cr stands for confidence region
  cr <- data.frame(
    tpf = tp / (tp + fn),
    fpf = fp / (fp + tn),
    tpf.min = tpf.ci[1],
    tpf.max = tpf.ci[2],
    fpf.min = fpf.ci[1],
    fpf.max = fpf.ci[2]
  )
  
  if(plot.it){
    cr.plot <- ggplot(data = cr) +
      geom_point(mapping = aes(x = fpf, y = tpf)) + 
      geom_rect(
        mapping = aes(
          xmin = fpf.min, 
          xmax = fpf.max, 
          ymin = tpf.min, 
          ymax = tpf.max
        ),
        color = "black", fill = NA
      ) + 
      annotate(
        "text", 
        x = 0.5, y = 0.1, 
        label = paste(
          "Sensitivity: ", round(cr$tpf, 2),
          " (", round(cr$tpf.min, 2), 
          ", ", round(cr$tpf.max, 2), ")", 
          sep = ""
        ), 
        size = 4
      ) + 
      annotate(
        "text", 
        x = 0.5, y = 0.05, 
        label = paste(
          "1 - Specificity: ", round(cr$fpf, 2),
          " (", round(cr$fpf.min, 2), 
          ", ", round(cr$fpf.max, 2), ")", 
          sep = ""
        ), 
        size = 4
      ) + 
      geom_abline(intercept=0, slope=1, linetype = "dashed") + 
      labs(
        x = "1 - Specificity", y = "Sensitivity", 
        title = "Joint 95% confidence region for\nSensitivity and 1 - Specificity"
      ) + 
      xlim(0, 1) + ylim(0, 1) + 
      coord_fixed(ratio = 1)
    return(list(cr = cr, cr.plot = cr.plot))
  } else {
    return(list(cr = cr))
  }
}
# Example
ComputeCR.BDT(tp = 18, fn = 6,
             fp = 1, tn = 92, 
             one.sided = F)




ComputeSS.BDT.Phase2 <- function(
  TPF_0 = 0.75, FPF_0 = 0.2,
  TPF_1 = 0.9, FPF_1 = 0.05,
  alpha = 0.1, beta = 0.1){
  
  # Compute the phase 2 sample size for evaluating the Binary Diagnostic Test (BDT)
  #
  # Args: TPF_0, FPF_0: minimally acceptable sensitivigy and 1 - specificity
  #       TPF_1, FPF_1: sensitivigy and 1 - specificity we want to achieve
  #       alpha: significance level
  #       beta: 1 - power
  #
  # Returns: a list with two elements:
  #          n.diseased, n.nondiseased: number of diseased and non-diseased patients
  #
  # Xinkai Zhou @UCLA DOMStat
  
  n.diseased <- 
    (qnorm(sqrt(1 - alpha)) * sqrt(TPF_0 * (1 - TPF_0)) +
       qnorm(sqrt(1 - beta)) * sqrt(TPF_1 * (1 - TPF_1)))^2 /
    (TPF_1 - TPF_0) ^ 2
  n.nondiseased <- 
    (qnorm(sqrt(1 - alpha)) * sqrt(FPF_0 * (1 - FPF_0)) +
       qnorm(sqrt(1 - beta)) * sqrt(FPF_1 * (1 - FPF_1)))^2 /
    (FPF_1 - FPF_0) ^ 2
  return(
    list(
      n.diseased = ceiling(n.diseased),
      n.nondiseased =  ceiling(n.nondiseased)
    )
  )
}

# Example
ComputeSS.BDT.Phase2(
  TPF_0 = 0.75, FPF_0 = 0.2,
  TPF_1 = 0.9, FPF_1 = 0.05,
  alpha = 0.1, beta = 0.1
)



SimulatePower.BDT.Phase2 <- function(
  n.diseased = 64, n.nondiseased = 46,
  TPF_0 = 0.75, FPF_0 = 0.2,
  TPF_1 = 0.9, FPF_1 = 0.05, 
  conf.level = 0.95,
  B = 500, seed = 185){
  # Obtain the simulated power using the given sample size.
  # Parameters are similar as above.
  # 
  # Xinkai Zhou @UCLA DOMStat
  SimulatePower.BDT.Phase2.Subroutine <- 
    function(n.diseased.sub = n.diseased, 
             n.nondiseased.sub = n.nondiseased,
             TPF_0.sub = TPF_0, FPF_0.sub = FPF_0,
             TPF_1.sub = TPF_1, FPF_1.sub = FPF_1,
             conf.level.sub = conf.level){
      # Subroutine for one iteration within simulation
      diseased <- sample(
        c("testPositive", "testNegative"), 
        size = n.diseased.sub, replace = T, 
        prob = c(TPF_1.sub, 1 - TPF_1.sub)
      )
      nondiseased <- sample(
        c("testPositive", "testNegative"), 
        size = n.nondiseased.sub, replace = T, 
        prob = c(FPF_1.sub, 1 - FPF_1.sub)
      )
      cr <- ComputeCR.BDT(
        tp = sum(diseased == "testPositive"), 
        fn = sum(diseased == "testNegative"),
        fp = sum(nondiseased == "testPositive"), 
        tn = sum(nondiseased == "testNegative"),
        conf.level = conf.level.sub,
        one.sided = T,
        plot.it = T
      )$cr
      return(
        ifelse(cr$tpf.min > TPF_0.sub & cr$fpf.max < FPF_0.sub,
               1, 0)
      )
    }
  
  set.seed(seed)
  cat("Power from ", B, " simulations = ", 
      sum(replicate(n = B, expr = SimulatePower.BDT.Phase2.Subroutine())) / B)
}
# Example
SimulatePower.BDT.Phase2(
  n.diseased = 64, n.nondiseased = 46,
  TPF_0 = 0.75, FPF_0 = 0.2,
  TPF_1 = 0.9, FPF_1 = 0.05, 
  conf.level = 0.95,
  B = 500, seed = 185
)


ComputeSS.BDT.Phase3 <- function(
  delta_0_T = 1, delta_0_F = 1.5,
  TPF_A = 0.8, FPF_A = 0.01,
  TPF_B = 0.75, FPF_B = 0.01,
  alpha = 0.05, beta = 0.1){
  # Compute the phase 3 sample size for comparing the Binary Diagnostic Tests (BDT)
  #
  # Args: delta_0_T, delta_0_F: parameters for specifying null hypothesis
  #       TPF_B, FPF_B: sensitivigy and 1 - specificity of the old test
  #       TPF_A, FPF_A: sensitivigy and 1 - specificity we want to the 
  #                     new test achieve
  #       alpha, beta: significance level and 1 - power
  #
  # Xinkai Zhou @UCLA DOMStat
  
  delta_1_T <- TPF_A / TPF_B
  delta_1_F <- FPF_A / FPF_B
  TPPF <- (delta_1_T + 1) * TPF_B - 1
  FPPF <- (delta_1_F + 1) * FPF_B - 1
  FPPF <- ifelse(FPPF < 0, 0, FPPF)
  n.diseased <- 
    ((qnorm(sqrt(1 - beta)) + qnorm(sqrt(1 - alpha))) / log(delta_1_T / delta_0_T))^2 * 
    ((delta_1_T + 1) * TPF_B - 2 * TPPF) / 
    (delta_1_T * TPF_B^2)
  n.nondiseased <- 
    ((qnorm(sqrt(1 - beta)) + qnorm(sqrt(1 - alpha))) / log(delta_1_F / delta_0_F))^2 * 
    ((delta_1_F + 1) * FPF_B - 2 * FPPF) / 
    (delta_1_F * FPF_B^2)
  
  return(
    list(
      n.diseased = ceiling(n.diseased),
      n.nondiseased =  ceiling(n.nondiseased)
    )
  )
}
# Example
ComputeSS.BDT.Phase3(
  delta_0_T = 1, delta_0_F = 10,
  TPF_A = 0.9, FPF_A = 0.01,
  TPF_B = 0.75, FPF_B = 0.01,
  alpha = 0.05, beta = 0.2
)


