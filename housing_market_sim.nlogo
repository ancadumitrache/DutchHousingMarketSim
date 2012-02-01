patches-own [price vacancy quality lifetime price-distr loc-average homeless realtor-nr in-realtor-area for-sale last-sold-at last-sold-for price-by-recent-sales price-all price-by-realtor1 price-by-realtor2 price-by-realtor3 price-by-realtor4 price-by-realtor5 price-by-realtor6 price-by-realtor7 price-by-realtor8 offers]

breed [agents agent]
agents-own [income mortgage-value mortgage-duration mortgage-repayment trade-down-plan mover newcomer search-length homeless-period moved-this-tick savings]

breed [realtors realtor]
realtors-own [optimism territory sales]

globals [demolished neg-equity transactions total-offers transaction-cycles transfer-tax step]


to setup
  clear-all
  setup-houses
  setup-realtors
  setup-agents
  setup-quality
  do-plots
  
  export-world "test-setup.csv"
  set step 0
end


to setup-houses
 ;; initializes house prices at a random value within 6 ranges that are equally distributed. Cheaper houses are indicated in blue, more expensive ones in red. 
 ;; initializes a proportion of the houses as inhabited and not for sale, the other ones as vacant and for sale
 ;; assigns to the houses a quality factor using the assign-quality procedure 

  ask patches [
    set in-realtor-area false
    set last-sold-at 0
    
    ifelse (1 + (random 100)) <= Density [
      set price-distr (random 6)
      
        ifelse price-distr = 0 [
          set pcolor (blue + price-distr)
          set price (75000 + (random 75001))
        ][
        ifelse price-distr = 1 [
          set pcolor blue + price-distr
          set price (150000 + (random 50001))
        ][
        ifelse price-distr = 2 [
          set pcolor (blue + price-distr)
          set price (200000 + (random 50001))
        ][
        ifelse price-distr = 3 [
          set pcolor (red + 2)
          set price (250000 + (random 50001))
        ][
        ifelse price-distr = 4 [
          set pcolor (red + 1)
          set price (300000 + (random 100001))
        ][
        set pcolor red
        set price (400000 + (random 1600001))
        ]
        ]]]]
      
      set last-sold-for price
      
      ifelse (random 100) < InitialVacancy [
        set vacancy true
        set for-sale true
      ]
      [
        set vacancy false
        set for-sale false
      ]
      
      set lifetime random-exponential HouseMeanLifetime
      set homeless 0
    ]
    [
      set pcolor green
      set vacancy false
      set for-sale false
    ]
  ]
end

to setup-agents
;; agents (home owners) are indicated by black dots and are assigned to all houses that are initialized as 'non-vacant'.
;; agents are assigned an income and a mortgage (value, duration and yearly repayment value)

  ifelse TransferTax = "6 %" [
    set transfer-tax 0.06
  ][
    set transfer-tax 0.02
  ]
  set-default-shape agents "dot"

  let agent-nr 0
  ask patches [
    if (vacancy = false) and (pcolor != green) [
      set agent-nr (agent-nr + 1)
    ]
  ]
  create-agents agent-nr
  
  let total 0
  ask patches [
    let x pxcor
    let y pycor
    if (vacancy = false) and (pcolor != green) [
      ask agent (total + 8) [setxy x y]
      set total (total + 1)
    ]
  ]

  ask patches [
    let x pxcor
    let y pycor
    let house-price price
    
    ask agents with [xcor = x and ycor = y] [
      if (xcor = x and ycor = y) [
        ;; set income (random-gamma 1.3 (0.00002 * MeanIncome)) * MeanIncome
        set income (random-gamma (MeanIncome / (MeanIncome - ModeIncome)) (1 / (MeanIncome - ModeIncome)))
        ;; set income random-gamma 35 0.001
        
        set mortgage-value ((1.04 + transfer-tax) * house-price)
        set mortgage-duration MortgageDuration
        set mortgage-repayment ((mortgage-value / mortgage-duration) + (InterestRate * mortgage-value / 100))
        
        set mover false
        set color black
        set newcomer false
      ]
    ]
  ]
end

to setup-quality
;;assigns to each house a quality factor

  ask patches [
    if pcolor != green [
      let average 0
      let avg-num 0
      ask patches in-radius Locality [
        set average (average + price)
        set avg-num (avg-num + 1)
      ]
      set quality (average / (avg-num * price))
    ]
  ]
end

to setup-realtors
;; creates 8 realtors (centers of realtor areas), indicated by a yellow patch
;; assigns all houses to one or more realtors

  set-default-shape realtors "circle"
  create-realtors 8
  
  ask realtors [
    set color yellow
    ask patches in-radius RealtorTerritory [
      set in-realtor-area true
    ]
  ]
  
  ask realtor 0 [ setxy 8 16 ]
  ask realtor 1 [ setxy 16 8 ]
  ask realtor 2 [ setxy -8 16 ]
  ask realtor 3 [ setxy 16 -8 ]
  ask realtor 4 [ setxy 8 -16 ]
  ask realtor 5 [ setxy -16 8 ]
  ask realtor 6 [ setxy -8 -16 ]
  ask realtor 7 [ setxy -16 -8 ]
  
  ask patches [
    if (pcolor != green) [
      let x pxcor
      let y pycor
      let house-price price
      
      let realtor-no -1
      ask min-one-of realtors [abs ((x - xcor) + (y - ycor))] [
        set realtor-no who
      ]
      set realtor-nr realtor-no
    ]
  ]
end

to go
;;keeps track of the number of ticks
;;makes the simulation stop after 1500 ticks (i.e., 375 years)

  one-tick
  set step (step + 1)
  if step > 200 [stop]
end

to one-tick
;;captures the algorithm of one iteration
  assess-houses
  update-income
  exit-and-enter
  kill-homeless-people
  adopt-trade-plan
  drop-house-prices
  transactions-cycle
  do-plots
  debug
end


to assess-houses
;; creates new vacant and available houses
;; assigns to each newly constructed house a price and quality 
;; demolishes houses that are outdated or that are not sold within the maximum period

  set demolished 0
  
  ask patches [
    ifelse pcolor = green [
      if ((random-float 100) < HouseConstructionRate) [
        set price-distr (random 6)
        ifelse price-distr = 0 [
          set pcolor (blue + price-distr)
          set price (75000 + (random 75001))
        ][
        ifelse price-distr = 1 [
          set pcolor blue + price-distr
          set price (150000 + (random 50001))
        ][
        ifelse price-distr = 2 [
          set pcolor (blue + price-distr)
          set price (200000 + (random 50001))
        ][
        ifelse price-distr = 3 [
          set pcolor (red + 2)
          set price (250000 + (random 50001))
        ][
        ifelse price-distr = 4 [
          set pcolor (red + 1)
          set price (300000 + (random 100001))
        ][
        set pcolor red
        set price (400000 + (random 1600001))
        ]
        ]]]]

        set vacancy true
        set for-sale true
        
        set homeless 0
        set lifetime random-exponential HouseMeanLifetime
        
        let average 0
        let avg-number 0
        ask patches in-radius Locality [
          set average (average + price)
          set avg-number (avg-number + 1)
        ]
        set quality (average / (avg-number * price))
        set last-sold-for price
      ]
    ]
    [
      if (pcolor != green)[
        ifelse ((lifetime < 1) or  ((vacancy = true) and (price < ((mean [price] of patches) / 10))))  [
          set pcolor green
          set demolished (demolished + 1)
          let x pxcor
          let y pycor
          let val-income 0
          set vacancy false
          set for-sale false
          ask agents [
            if (xcor = x and ycor = y) [
              set val-income income
              hide-turtle
              set newcomer true
              set mover true
              set homeless-period MaxHomelessPeriod
            ]
          ]
        ]
        [
          if (step mod 4 = 0) [
            set lifetime lifetime - 1
          ]
        ]
      ]
    ]
  ]
end

to exit-and-enter
;; makes a proportion of homeowners leave town and set their house for sale
;; makes a proportion of agents enter town ('newcomers')  

  let house-list (list)
  ask n-of (ExitRate / 100 * (count agents)) agents
  [
    let x xcor
    let y ycor
    set house-list lput (list xcor ycor) house-list
    die
  ]
  foreach house-list [
    let i 0
    let x 100
    let y 100
    foreach ? [
      ifelse (i = 0) [
        set x ?
      ][
        set y ?
      ]
      
      set i (i + 1)
    ]
    
    if (x != 100 and y != 100) [
      ask patch x y [
        ;; set house as vacant
        set vacancy true
        set for-sale true
        update-house-price pxcor pycor
      ]
    ]
  ]
  
  create-agents (EntryRate / 100 * (count agents))
  ask agents [
    if (income = 0) [
      set income (random-gamma (MeanIncome / (MeanIncome - ModeIncome)) (1 / (MeanIncome - ModeIncome)))
      hide-turtle
      set newcomer true
      set mover true
      set homeless-period MaxHomelessPeriod
    ]
  ]
end

to update-income
;; every year income is adjusted to inflation, mortgage duration is lowered by 1 and mortgage value and repayment are adjusted likewise
;; some agents are affected by an income increase or decrease
  ask agents [
    if (step mod TicksPerYear = 0) [
      set income ((100 - inflation) * (income / 100))
      if (newcomer = false) [
        set mortgage-duration (mortgage-duration - 1)
        set mortgage-value (mortgage-value - mortgage-repayment)
        set mortgage-repayment ((mortgage-value / MortgageDuration) + (InterestRate * mortgage-value / 100))
      ]
    ]
  ]
  ask n-of ((Shocked / 100) * (count agents)) agents [
    set income (income * 1.2)
  ]
  ask n-of ((Shocked / 100) * (count agents)) agents [
    set income (income * 0.8)
  ]
end  

to adopt-trade-plan
;;assesses whether mortgage repayment and income are out of balance and makes agents adopt the plan to trade up or down 
  ask patches with [pcolor != green] [
    let x pxcor
    let y pycor
    let change-trade-plan false 

    ifelse any? agents with [xcor = x and ycor = y] [
      set vacancy false
      ask agents with [xcor = x and ycor = y] [
        ifelse (mortgage-repayment / income) > (2 * Affordability / 100) [
          if mover = false [
            set homeless-period MaxHomelessPeriod
          ]
          set trade-down-plan true
          set mover true
          set change-trade-plan true
        ][ 
        ifelse (mortgage-repayment / income) < (0.5 * Affordability / 100) [
          if mover = false [
            set homeless-period MaxHomelessPeriod
          ]
          set trade-down-plan false
          set mover true
          set change-trade-plan true
        ][
        set mover false
        ]]
      ]
      ifelse change-trade-plan = true [
        set for-sale true
        update-house-price pxcor pycor
      ][
      set for-sale false
      ]
    ][
      set vacancy true
      set for-sale true
    ]
  ]
end
  
 
 to drop-house-prices
  ask patches with [for-sale = true and pcolor != green] [
            set price (price * (100 - PriceDropRate) / 100)
            set homeless (homeless + 1)
            recolour-house pxcor pycor
  ]
end
  

to update-house-price [x y]
;; precomputes necessary data for price valuations by realtors 

    let realtor1-sum 0
    let realtor1-nr 0
    let realtor2-sum 0
    let realtor2-nr 0
    let realtor3-sum 0
    let realtor3-nr 0
    let realtor4-sum 0
    let realtor4-nr 0
    let realtor5-sum 0
    let realtor5-nr 0
    let realtor6-sum 0
    let realtor6-nr 0
    let realtor7-sum 0
    let realtor7-nr 0
    let realtor8-sum 0
    let realtor8-nr 0
    
    let recent-sum 0
    let recent-nr 0
    
    let total-sum 0
    let total-nr 0
    
    ask patches in-radius Locality [
      ifelse  (realtor-nr = 0 and step - last-sold-at <= RealtorMemory) [
        set realtor1-sum (realtor1-sum + last-sold-for)
        set realtor1-nr (realtor1-nr + 1)
      ][
      ifelse  (realtor-nr = 1 and step - last-sold-at <= RealtorMemory) [
        set realtor2-sum (realtor2-sum + last-sold-for)
        set realtor2-nr (realtor2-nr + 1)
      ][
      ifelse  (realtor-nr = 2 and step - last-sold-at <= RealtorMemory) [
        set realtor3-sum (realtor3-sum + last-sold-for)
        set realtor3-nr (realtor3-nr + 1)
      ][
      ifelse  (realtor-nr = 3 and step - last-sold-at <= RealtorMemory) [
        set realtor4-sum (realtor4-sum + last-sold-for)
        set realtor4-nr (realtor4-nr + 1)
      ][
      ifelse  (realtor-nr = 4 and step - last-sold-at <= RealtorMemory) [
        set realtor5-sum (realtor5-sum + last-sold-for)
        set realtor5-nr (realtor5-nr + 1)
      ][
      ifelse  (realtor-nr = 5 and step - last-sold-at <= RealtorMemory) [
        set realtor6-sum (realtor6-sum + last-sold-for)
        set realtor6-nr (realtor6-nr + 1)
      ][
      ifelse  (realtor-nr = 6 and step - last-sold-at <= RealtorMemory) [
        set realtor7-sum (realtor7-sum + last-sold-for)
        set realtor7-nr (realtor7-nr + 1)
      ][
        set realtor8-sum (realtor8-sum + last-sold-for)
        set realtor8-nr (realtor8-nr + 1)
      ]]]]]]]
      
      if (step - last-sold-at <= RealtorMemory) [
        set recent-sum (recent-sum + last-sold-for)
        set recent-nr (recent-nr + 1)
      ]
      
      set total-sum (total-sum + last-sold-for)
      set total-nr (total-nr + 1)
    ]
    
    ifelse (realtor1-sum != 0) [ set price-by-realtor1 (realtor1-sum / realtor1-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor1 0 ]
    ifelse (realtor2-sum != 0) [ set price-by-realtor2 (realtor2-sum / realtor2-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor2 0 ]
    ifelse (realtor3-sum != 0) [ set price-by-realtor3 (realtor3-sum / realtor3-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor3 0 ]
    ifelse (realtor4-sum != 0) [ set price-by-realtor4 (realtor4-sum / realtor4-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor4 0 ]
    ifelse (realtor5-sum != 0) [ set price-by-realtor5 (realtor5-sum / realtor5-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor5 0 ]
    ifelse (realtor6-sum != 0) [ set price-by-realtor6 (realtor6-sum / realtor6-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor6 0 ]
    ifelse (realtor7-sum != 0) [ set price-by-realtor7 (realtor7-sum / realtor7-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor7 0 ]
    ifelse (realtor8-sum != 0) [ set price-by-realtor8 (realtor8-sum / realtor8-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-realtor8 0 ]
    
    ifelse (recent-sum != 0) [ set price-by-recent-sales (recent-sum / recent-nr * (100 + RealtorOptimism) / 100) ] [ set price-by-recent-sales 0 ]
    set price-all (total-sum / total-nr  * (100 + RealtorOptimism) / 100)
    
    
 ;; ]
  
  ifelse (in-realtor-area = true) [
    ask realtors [
      let realtor-no who
      ask patches with [pxcor = x and pycor = y] in-radius RealtorTerritory [
          realtor-evaluation realtor-no
      ]
    ]
  ][
      realtor-evaluation realtor-nr
  ]
  
end

to realtor-evaluation [realtor-no]
;; valuation algorithm that each realtor performs; see report. 
;; sets a price for each house that is for sale. 
;; updates patch color in case the house moves to a different price category


  let price-this-realtor 0
  let price-all-realtors 0
  let final-price 0
  
  ifelse (realtor-no = 0) [
    set price-this-realtor price-by-realtor1
  ][
  ifelse (realtor-no = 1) [
    set price-this-realtor price-by-realtor2
  ][
  ifelse (realtor-no = 2) [
    set price-this-realtor price-by-realtor3
  ][
  ifelse (realtor-no = 3) [
    set price-this-realtor price-by-realtor4
  ][
  ifelse (realtor-no = 4) [
    set price-this-realtor price-by-realtor5
  ][
  ifelse (realtor-no = 5) [
    set price-this-realtor price-by-realtor6
  ][
  ifelse (realtor-no = 6) [
    set price-this-realtor price-by-realtor7
  ][
    set price-this-realtor price-by-realtor8
  ]]]]]]]
  
  ;; the realtor has made sales within the Locality in RealtorMemory
  ifelse (price-this-realtor != 0) [
    set final-price price-this-realtor
  ][
  ;; there were sales made within the Locality in RealtorMemory
  ifelse (price-by-recent-sales != 0) [
    set final-price price-by-recent-sales
  ][
    set final-price price-all
  ]]
  
  if (final-price > price) [
    set price final-price
    set realtor-nr realtor-no
    recolour-house pxcor pycor
  ]
  
end

to recolour-house [x y]
  ask patch x y [
    ifelse (price < 150000) [
      set pcolor blue
      set price-distr 0
    ][
    ifelse (price < 200000) [
      set pcolor blue + 1
      set price-distr 1
    ][
    ifelse (price < 250000) [
      set pcolor blue + 2
      set price-distr 2
    ][
    ifelse (price < 300000) [
      set pcolor red + 3
    ][
    ifelse (price < 400000) [
      set pcolor red + 1
      set price-distr 4
    ][
      set pcolor red
      set price-distr 5
    ]]]]]
  ]
end

to transactions-cycle
;; makes agents with a trade plan put an offer on the house that is within but maximally uses their budget
;; makes agents move to the house for which they were the first to put an offer
;; adjusts agents' financial variables after moving

  ask patches [
    set offers (list)
  ]
  ask agents [
    set moved-this-tick false
  ]
  
  set transactions 0
  set total-offers 0
  set transaction-cycles 0
  
  while [move and transaction-cycles < 53 / TicksPerYear] [ set transaction-cycles (transaction-cycles + 1) ]
end

to-report move
  ;; get savings
  ask patches with [pcolor != green and for-sale = true] [
    let house-price price
    let x pxcor
    let y pycor
    
    if any? agents with [xcor = x and ycor = y] [
      ask agents with [xcor = x and ycor = y] [
        set savings house-price
      ]
    ]
  ]
  
  let house-list (list)
  ask agents with [mover = true] [                                                                     
    set search-length search-length + 1 
    if search-length <= BuyerSearchLength [
      let mover-budget (2 * income * Affordability / 100)
      
      ;; browse for houses that are for sale and vacant
      let buyer who
      let salary income
      
      let mortgage mortgage-value
      if any? patches with [vacancy = true and empty? offers and pcolor != green and
          (((price * (1.04 + transfer-tax) + mortgage) / MortgageDuration) + (InterestRate / 100) * (price * (1.04 + transfer-tax) + mortgage)) <= mover-budget and
          (((price * (1.04 + transfer-tax) + mortgage) / MortgageDuration) + (InterestRate / 100) * (price * (1.04 + transfer-tax) + mortgage)) >= 0.5 * salary * Affordability / 100]
      [
        ask min-one-of patches with [vacancy = true and empty? offers and
          (((price * (1.04 + transfer-tax) + mortgage) / MortgageDuration) + (InterestRate / 100) * (price * (1.04 + transfer-tax) + mortgage)) <= mover-budget and
          (((price * (1.04 + transfer-tax) + mortgage) / MortgageDuration) + (InterestRate / 100) * (price * (1.04 + transfer-tax) + mortgage)) >= 0.5 * salary * Affordability / 100]
        [abs (mover-budget - (((price * (1.04 + transfer-tax) + mortgage) / MortgageDuration) + (InterestRate / 100) * (price * (1.04 + transfer-tax) + mortgage)))]
        [
          set offers lput buyer offers
        ;;  file-write pxcor
        ;;  file-write pycor
          set total-offers (total-offers + 1)
        ]
      ]
    ]
  ]
  ;; export-world "offer-testing.csv"
  
  ask patches with [vacancy = true and pcolor != green] [
    let sold-house false
    let x pxcor
    let y pycor
    let house-price price
    ifelse any? agents with [xcor = x and ycor = y and newcomer = false] [
      ;;file-open "agents.txt"
      ;;file-write x
      ;;file-write y
      ;;file-print ", "
      ;;file-close
      set vacancy false
    ][
    
      ifelse empty? offers [
      ][
      ask agent first offers [
        set house-list lput (list x y) house-list
        
        setxy x y
        set moved-this-tick true
        set mover false
        set newcomer false   
        set color black
        show-turtle 
        
        set savings (savings - mortgage-value)
        ifelse savings < house-price [
          set mortgage-value (house-price - savings) * (1.04 + transfer-tax)
          set mortgage-duration MortgageDuration
          set mortgage-repayment ((mortgage-value / mortgage-duration) + (InterestRate * mortgage-value / 100))
        ][
          set mortgage-value 0
          set mortgage-duration 0
          set mortgage-repayment 0
        ]
      
      ]
      
      set vacancy false
      set for-sale false
      set last-sold-for price
      set last-sold-at step
      
      set transactions (transactions + 1)
      set sold-house true
      ]
    ]
  ]
  
  if empty? house-list [ report false ]
  
  ;; put empty houses on the market
  foreach house-list [
    let i 0
    let x 100
    let y 100
    foreach ? [
      ifelse i = 0 [ set x ? ] [ set y ? ]
      set i (i + 1)
    ]
    
    if (x != 100 or y != 100) [
      ask patch x y [
        set vacancy true
        set for-sale true
        ;; update-house-price pxcor pycor
      ]      
    ]
  ]
  
  ;; remove offers from agents that have already relocated
  ask patches [
    let has-relocated true
    while [(empty? offers) = false and has-relocated = true] [
      let agent-who first offers
      ask agent agent-who [
        set has-relocated moved-this-tick 
      ]
      if (has-relocated = true) [
        set offers but-first offers
      ]
    ]
  ]
  
  report true                                      
end

to kill-homeless-people
  let house-list (list)
  file-open "dead-homeless.txt"
  
  ask agents with [mover = true or newcomer = true] [
      file-write xcor
      file-write ycor
      file-write homeless-period
      file-print "\n"
    ifelse (homeless-period > 0) [
      set homeless-period (homeless-period - 1)
    ][
      set house-list lput (list xcor ycor) house-list
      file-write xcor
      file-write ycor
      file-print "\n"
      die
    ]
  ]
  file-close
  
  foreach house-list [
    let i 0
    let x 100
    let y 100
    foreach ? [
      ifelse (i = 0) [
        set x ?
      ][
        set y ?
      ]
      
      set i (i + 1)
    ]
    
    if (x != 100 and y != 100) [
      ask patch x y [
        ;; set house as vacant
        set vacancy true
        set for-sale true
        update-house-price pxcor pycor
      ]
    ]
  ]
end

to do-plots
  set-current-plot "Movers"
  set-current-plot-pen "homeowners not moving"
  plot count agents with [newcomer = false and mover = false]
  set-current-plot-pen "homeowners trading up"
  plot count agents with [newcomer = false and mover = true and trade-down-plan = false]
  set-current-plot-pen "homeowners trading down"
  plot count agents with [newcomer = false and mover = true and trade-down-plan = true]
  set-current-plot-pen "newcomers"
  plot count agents with [newcomer = true]
  
  set-current-plot "Houses"
  set-current-plot-pen "all houses"
  plot count patches with [pcolor != green]
  set-current-plot-pen "empty houses"
  plot count patches with [pcolor != green and vacancy = true]
  set-current-plot-pen "for sale but still occupied"
  plot count patches with [pcolor != green and vacancy = false and for-sale = true]
  set-current-plot-pen "demolished"
  plot demolished
  set-current-plot-pen "in negative equity"
  plot neg-equity
  
  set-current-plot "House price distribution"
  set-current-plot-pen "all houses"
  histogram [price] of patches with [pcolor != green]
  set-current-plot-pen "for sale"
  histogram [price] of patches with [pcolor != green and for-sale = true]
  
  set-current-plot "Mean time on market"
  set-current-plot-pen "time"
  plot mean [homeless] of patches with [vacancy = true]
  
  set-current-plot "Transactions"
  set-current-plot-pen "transactions"
  plot transactions
  
  set-current-plot "Income distribution"
  set-current-plot-pen "income"
  histogram [income] of agents
  
  set-current-plot "Median house prices"
  set-current-plot-pen "for sale"
  plot median [price] of patches with [pcolor != green and for-sale = true]
  set-current-plot-pen "sold"
  plot median [price] of patches with [pcolor != green and for-sale = false]
  
  set-current-plot "Median house price / Median income"
  set-current-plot-pen "ratio"
  plot ((median [price] of patches with [pcolor != green]) / (median [income] of agents))
  
  set-current-plot "Mean mortgage repayment / income"
  set-current-plot-pen "default"
  plot (mean [mortgage-repayment / income] of agents with [mortgage-repayment != 0])
  
  export-all-plots "plots.csv"
  
  if step >= 100 [
    file-open "median-price.txt"
    file-write median [price] of patches with [pcolor != green and for-sale = false]
    file-print "\n"
    file-close
    
    file-open "transactions.txt"
    file-write transactions
    file-print "\n"
    file-close
    
    file-open "price-income.txt"
    file-write ((median [price] of patches with [pcolor != green]) / (median [income] of agents))
    file-print "\n"
    file-close
    
    file-open "market-time.txt"
    file-write mean [homeless] of patches with [vacancy = true]
    file-print "\n"
    file-close
  ]
end

to debug
  file-open "agents.txt"
  ask patches with [pcolor != green] [
    let x pxcor
    let y pycor
    let people count agents with [xcor = x and ycor = y and newcomer = false]
    if people > 1 [
      file-write step
      file-write x
      file-write y
      file-write people
      file-print "\n"
      file-print "\n"
    ]
    
  ]
  file-close
end

@#$#@#$#@
GRAPHICS-WINDOW
515
25
1137
668
25
25
12.0
1
10
1
1
1
0
1
1
1
-25
25
-25
25

CC-WINDOW
5
826
1911
921
Command Center
0

SLIDER
11
10
183
43
inflation
inflation
0.0
20
0.0
0.1
1
%pa

SLIDER
11
44
183
77
InterestRate
InterestRate
0
20
7.0
0.1
1
%pa

SLIDER
10
77
182
110
TicksPerYear
TicksPerYear
0
12
4
1
1
NIL

SLIDER
10
141
182
174
Affordability
Affordability
0
100
25
1
1
%

SLIDER
10
206
182
239
ExitRate
ExitRate
0
10
2
1
1
NIL

SLIDER
10
237
182
270
EntryRate
EntryRate
0
10
6
1
1
NIL

SLIDER
10
269
182
302
MeanIncome
MeanIncome
0
100000
36000
1000
1
�

SLIDER
10
301
182
334
Shocked
Shocked
0
100
20
1
1
NIL

SLIDER
9
333
189
366
MaxHomelessPeriod
MaxHomelessPeriod
0
30
5
1
1
ticks

SLIDER
10
365
182
398
BuyerSearchLength
BuyerSearchLength
0
100
12
1
1
NIL

SLIDER
10
422
182
455
RealtorTerritory
RealtorTerritory
0
50
10
1
1
NIL

SLIDER
10
455
182
488
Locality
Locality
0
10
3
1
1
NIL

SLIDER
9
521
181
554
PriceDropRate
PriceDropRate
0
10
3
1
1
%

SLIDER
9
551
181
584
RealtorOptimism
RealtorOptimism
-10
10
2
1
1
%

SLIDER
219
489
465
522
HouseConstructionRate
HouseConstructionRate
0.0
1.0
1.0
0.01
1
% per tick

SLIDER
220
455
392
488
Density
Density
0
100
70
1
1
%

SLIDER
218
284
410
317
HouseMeanLifetime
HouseMeanLifetime
0
500
198
1
1
years

SLIDER
218
318
403
351
MortgageDuration
MortgageDuration
0
100
30
1
1
years

CHOOSER
218
353
356
398
TransferTax
TransferTax
"2 %" "6 %"
1

SLIDER
10
488
182
521
RealtorMemory
RealtorMemory
0
10
9
1
1
ticks

BUTTON
235
125
298
158
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
235
168
298
201
NIL
go
T
1
T
OBSERVER
NIL
NIL

BUTTON
235
213
324
246
one tick
one-tick
NIL
1
T
OBSERVER
NIL
NIL

SLIDER
220
422
392
455
InitialVacancy
InitialVacancy
0
100
30
1
1
%

SLIDER
9
593
181
626
ModeIncome
ModeIncome
0
100000
35000
1000
1
�

PLOT
1145
35
1522
185
Movers
Time
Number
0.0
10.0
0.0
10.0
true
true
PENS
"homeowners not moving" 1.0 0 -16777216 true
"homeowners trading up" 1.0 0 -2674135 true
"homeowners trading down" 1.0 0 -13345367 true
"newcomers" 1.0 0 -10899396 true

PLOT
1522
35
1900
185
Houses
Time
Number
0.0
10.0
0.0
10.0
true
true
PENS
"all houses" 1.0 0 -16777216 true
"empty houses" 1.0 0 -13345367 true
"for sale but still occupied" 1.0 0 -2674135 true
"demolished" 1.0 0 -10899396 true
"in negative equity" 1.0 0 -7500403 true

PLOT
1523
192
1902
342
House price distribution
Euro
Number
75000.0
2000000.0
0.0
10.0
true
true
PENS
"all houses" 10000.0 1 -16777216 true
"for sale" 1.0 1 -2674135 true

PLOT
1145
349
1524
499
Mean time on market
Time
Ticks
0.0
10.0
0.0
10.0
true
false
PENS
"time" 1.0 0 -2674135 true

PLOT
1524
349
1902
499
Transactions
Time
Number
0.0
10.0
0.0
10.0
true
false
PENS
"transactions" 1.0 0 -16777216 true

PLOT
1145
192
1523
342
Income distribution
Euro
Number
0.0
500000.0
0.0
10.0
true
false
PENS
"income" 1000.0 1 -16777216 true

PLOT
1145
506
1524
656
Median house prices
Time
Euro
0.0
10.0
0.0
10.0
true
true
PENS
"for sale" 1.0 0 -2674135 true
"sold" 1.0 0 -16777216 true

PLOT
1524
506
1902
656
Median house price / Median income
Time
Ratio
0.0
10.0
0.0
10.0
true
false
PENS
"ratio" 1.0 0 -16777216 true

MONITOR
1577
691
1635
740
Agents
count agents
17
1

PLOT
1146
662
1526
812
Mean mortgage repayment / income
Time
Ratio
0.0
10.0
0.0
2.0
true
false

@#$#@#$#@
WHAT IS IT?
-----------
This section could give a general understanding of what the model is trying to show or explain.


HOW IT WORKS
------------
This section could explain what rules the agents use to create the overall behavior of the model.


HOW TO USE IT
-------------
This section could explain how to use the model, including a description of each of the items in the interface tab.


THINGS TO NOTICE
----------------
This section could give some ideas of things for the user to notice while running the model.


THINGS TO TRY
-------------
This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.


EXTENDING THE MODEL
-------------------
This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.


NETLOGO FEATURES
----------------
This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.


RELATED MODELS
--------------
This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.


CREDITS AND REFERENCES
----------------------
This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 3.1.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
