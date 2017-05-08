function [MODEL,INIT_CONDITIONS] = configureRobot(varargin)
%CONFIGROBOT setup or update the robot model and the initial conditions for
%            forward dynamics integration.
%
% Format:  [MODEL,INIT_CONDITIONS] = CONFIGUREROBOT(CONFIG)
%
% Inputs:  - CONFIG: it is the structure containing all user-defined 
%                    configuration parameters;
%                       
%                           ONLY FOR UPDATING THE DATA:
%
%          - chi_robotInit: a vector describing the robot state [13+2*ndof x 1]. 
%          - MODEL_OLD: it is a structure defining the robot model;        
%          - INIT_CONDITIONS_OLD: it is a structure containing initial conditions
%                             for forward dynamics integration.
%
% Output:  - MODEL: it is a structure defining the robot model;        
%          - INIT_CONDITIONS: it is a structure containing initial conditions
%                             for forward dynamics integration.
%         
% Author : Gabriele Nava (gabriele.nava@iit.it)
% Genova, March 2017

%% ------------Initialization----------------
global state;

CONFIG            = varargin{1};
if nargin == 4
    chi_robotInit       = varargin{2};
    MODEL_OLD           = varargin{3};
    INIT_CONDITIONS_OLD = varargin{4};
    % save the previous model and initial conditions structure into the new
    % one (to avoid losing data from ikin, gain tuning, ecc...)
    MODEL               = MODEL_OLD;
    INIT_CONDITIONS     = INIT_CONDITIONS_OLD;
end
    
%% Include configuration in the model structure
MODEL.CONFIG                = CONFIG; 
% number of robot DoFs
MODEL.ndof                  = 25;
% transmission ratio (in case of elastic joints)
MODEL.eta                   = 0.01;
% if true, it disables online visualizer (do not modify this option manually)
MODEL.disableVisForGraphics = false;
% define a time vector with fixed step (for graphics)
MODEL.timeTot               = MODEL.CONFIG.tStart:MODEL.CONFIG.sim_step:MODEL.CONFIG.tEnd;
% feet size
MODEL.feetSize              = [-0.050 0.100;    % xMin, xMax
                               -0.025 0.025];   % yMin, yMax 
         
%% Define joint positions or update them accordingly to the current state (finite state machine)
if strcmp(MODEL.CONFIG.demo_type,'yoga')
    if  state == 1
        % two feet balancing                   
        MODEL.CONFIG.feet_on_ground  = [1,1];   
    elseif state == 3
        % left foot balancing
        MODEL.CONFIG.feet_on_ground  = [1,0];
    elseif state == 7
        % two feet balancing
        MODEL.CONFIG.feet_on_ground  = [1,1];
    elseif state == 9
        % right foot balancing
        MODEL.CONFIG.feet_on_ground  = [0,1];
    elseif state == 13
        % two feet balancing
        MODEL.CONFIG.feet_on_ground  = [1,1]; 
    end 
    % initialize state machine references   
    SM     = initStateMachineYoga(MODEL, state, 'init');
    % initial joint positions
    qjInit = SM.qjRef;
       
else
    % initial joints position (NO STATE MACHINE)
    if sum(MODEL.CONFIG.feet_on_ground) == 2
        % initial conditions for balancing on two feet
        leftArmInit   = [ -20  30  0  45  0];
        rightArmInit  = [ -20  30  0  45  0];
        torsoInit     = [ -10   0  0];
        leftLegInit   = [  25.5   0   0  -18.5  -5.5  0];
        rightLegInit  = [  25.5   0   0  -18.5  -5.5  0];
        % joints configuration [rad]
        qjInit = transpose([torsoInit,leftArmInit,rightArmInit, ...
                            leftLegInit,rightLegInit])*(pi/180);
    
    elseif MODEL.CONFIG.feet_on_ground(1) == 1 && MODEL.CONFIG.feet_on_ground(2) == 0
        % initial conditions for the robot standing on the left foot
        qjInit = transpose([ 0.0462,-0.5256,-0.0269, ...
                             0.1874, 1.6258, 0.2462, 0.3053,-0.0948, ...
                            -0.3553, 1.8546, 0.7323, 0.3905,-0.1169, ...
                             0.1047, 0.2547, 0.0378, 0.0732, 0.0958, 0.1637, ...
                             0.2923, 0.8611, 1.2866,-1.7688, 0.4568,-0.0163]);  
    
    elseif MODEL.CONFIG.feet_on_ground(1) == 0 && MODEL.CONFIG.feet_on_ground(2) == 1 
        % initial conditions for the robot standing on the right foot
        qjInit = transpose([-0.0462, 0.5256, 0.0269, ...
                            -0.3553, 1.8546, 0.7323, 0.3905,-0.1169, ...
                             0.1874, 1.6258, 0.2462, 0.3053,-0.0948, ...
                             0.2923, 0.8611, 1.2866,-1.7688, 0.4568,-0.0163, ...
                             0.1047, 0.2547, 0.0378, 0.0732, 0.0958, 0.1637,]);         
    end
end

%% %%%%%%%%%% INITIAL ROBOT AND FLOATING BASE CONFIGURATION %%%%%%%%%%%% %%
% contact constraints
if sum(MODEL.CONFIG.feet_on_ground) == 2
    % two feet balancing
    MODEL.constraintLinkNames = {'l_sole','r_sole'};
    
elseif MODEL.CONFIG.feet_on_ground(1) == 1 && MODEL.CONFIG.feet_on_ground(2) == 0
    % left foot balancing
    MODEL.constraintLinkNames = {'l_sole'};
    
elseif MODEL.CONFIG.feet_on_ground(1) == 0 && MODEL.CONFIG.feet_on_ground(2) == 1
    % right foot balancing
    MODEL.constraintLinkNames = {'r_sole'};
end

% fixing the world reference frame w.r.t. the foot on ground position
[x_bInit,w_R_bInit]           = wbm_getWorldFrameFromFixLnk(MODEL.constraintLinkNames{1},qjInit);
qt_bInit                      = rotm2quat(w_R_bInit);
basePoseInit                  = [x_bInit; qt_bInit];
% in case the robot state is not already defined (state == 1), use the
% initial conditions for defining it
if ~exist('chi_robotInit','var')
    chi_robotInit             = [basePoseInit; qjInit; zeros(6,1); zeros(MODEL.ndof,1)];
end
% robot state
INIT_CONDITIONS.chi_robotInit = chi_robotInit;

%% Initial robot state (demuxed), dynamics and forward kinematics
% initial state (demuxed)
INIT_CONDITIONS.INITSTATE         = robotState(INIT_CONDITIONS.chi_robotInit,MODEL);
% initial dynamics
INIT_CONDITIONS.INITDYNAMICS      = robotDynamics(INIT_CONDITIONS.INITSTATE,MODEL);
% initial forward kinematics
INIT_CONDITIONS.INITFORKINEMATICS = robotForKinematics(INIT_CONDITIONS.INITSTATE,INIT_CONDITIONS.INITDYNAMICS);

% update robot state. This is done in case wbm_wrappers are called using optimized mode
wbm_updateState(qjInit,INIT_CONDITIONS.INITSTATE.dqj,[INIT_CONDITIONS.INITSTATE.dx_b; INIT_CONDITIONS.INITSTATE.w_omega_b]);
% set world frame. This is done in case wbm_wrappers are called using optimized mode
wbm_setWorldFrame(w_R_bInit,x_bInit,[0; 0; -9.81])

%% %%%%%%%% INITIAL GAINS AND REFERENCES (NO TUNING, NO IKIN) %%%%%%%%%% %%
% control gains (no gain tuning)
if strcmp(MODEL.CONFIG.demo_type,'yoga')
    % initial gains (state machine)
    MODEL.GAINS     = reshapeGains(SM.gainsVector,MODEL);
else
    % initial gains (no state machine)
    MODEL.GAINS     = gains(MODEL);
end
% joints and CoM references (no ikin) 
MODEL.REFERENCES.qjRef        = qjInit;
MODEL.REFERENCES.xCoMRef      = INIT_CONDITIONS.INITFORKINEMATICS.xCoM;
MODEL.REFERENCES.feetRef      = [INIT_CONDITIONS.INITFORKINEMATICS.poseLFoot_ang;INIT_CONDITIONS.INITFORKINEMATICS.poseRFoot_ang];
% in case of one foot balancing the (x,y) components of CoM are setted to
% be in the center of support polygon
if MODEL.CONFIG.feet_on_ground(2) == 0
    % left foot balancing 
    MODEL.REFERENCES.xCoMRef([1,2]) = INIT_CONDITIONS.INITFORKINEMATICS.poseLFoot_qt([1,2]);
elseif MODEL.CONFIG.feet_on_ground(1) == 0
    % right foot balancing
    MODEL.REFERENCES.xCoMRef([1,2]) = INIT_CONDITIONS.INITFORKINEMATICS.poseRFoot_qt([1,2]);
end

end
