MACHINE FT_PACKAGE_GLUE_ERC20_Base
SEES FT_TYPES
CONSTANTS funSig_loc, eventSig_loc
PROPERTIES
  funSig_loc = {
f_totalSupply|->(<>,<t_UINT>),f_balanceOf|->(<t_ADDR>,<t_UINT>),f_transfer|->(<t_ADDR,t_UINT>,<>),f_allowance|->(<t_ADDR,t_ADDR>,<t_UINT>),f_approve|->(<t_ADDR,t_UINT>,<>),f_transferFrom|->(<t_ADDR,t_ADDR,t_UINT>,<>)  } &
  eventSig_loc = {
e_Transfer|-><t_ADDR,t_ADDR,t_UINT>,e_Approval|-><t_ADDR,t_ADDR,t_UINT>  }
ASSERTIONS funSig = funSig_loc & eventSig = eventSig_loc
END