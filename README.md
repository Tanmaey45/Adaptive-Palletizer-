# Adaptive Palletizing using Simulation Optimization
This repo involves approach to solve the MathWorks Challenge Project - Adaptive Palletizing with Simulation Optimization



**Abstract**

Traditional palletizing systems using teach pendants lack flexibility, making them unsuitable for handling varying box sizes or dynamic layout changes. This leads to inefficiencies, increased cycle times, and a higher risk of product damage. With rising demand for agile automation in logistics and manufacturing, there is a need for a flexible, optimized palletizing system. This project proposes the use of optimization techniques and model-based design to develop a flexible palletizing system, leveraging collaborative robots like Universal Robots, known for their ease of use and safety.

![Alt text](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/adaptive.png)


**Introduction**

To address these challenges, this project develops a flexible and intelligent palletizing solution using model-based design, trajectory optimization, and layered packing strategies. The approach leverages pre-uploaded data—such as box dimensions and weights—and generates optimized pallet layouts using MATLAB-Python integration. It enables a Universal Robot to execute deterministic, collision-free placements with minimal energy consumption. QR code integration, temporary staging platforms, and 2-layer packing strategies further enhance the system’s robustness. This project demonstrates how simulation and real-time adjustments can be combined to meet the rising demand for adaptive automation in smart manufacturing.

This project builds upon the existing MATLAB [Robot Palletizing Example](https://www.mathworks.com/help/robotics/ug/palletize-boxes-using-cobot-with-simulink-3d-animation.html), which originally palletized boxes of fixed dimensions and spawn.

## Approach to the problem

The steps suggested in the [Github page of challenge](https://github.com/mathworks/MATLAB-Simulink-Challenge-Project-Hub/blob/main/projects/Adaptive%20Palletizing%20with%20Simulation%20Optimization/README.md) were followed, and a few were changed according to the scope of knowledge. The steps are listed down below in short. Find detailed description of each step. 

**1. Problem Setup**
- Boxes of variable size and weight are generated.
- A predefined mode strategy is chosen:
  - Packers input box data (dimensions, weight) in advance.
  - Boxes arrive randomly on a conveyor.
    
**2. Box Data Handling**
- Box dimensions and weights are stored in an Excel file.
- A MATLAB function reads the box data and passes it to the optimizer.
  
**3. Optimization Logic**
- A Python-based 3D bin-packing algorithm is used:
    - Objective: Optimize box placement for a given pallet volume and height.
    - Constraints: No overhang > 20%, stable stacking (heavy/dense at bottom).
    - All boxes are variable in length and breadth but are assumed to be of same height (practical approach)
    - Rotation of boxes is allowed

- Packing improved using
  - Weight-based sorting: Heavy boxes at the bottom.
  - Density sorting: Denser (more stable) boxes are prioritized below lighter ones.


  Later, the Python code is converted into a MATLAB (.m) file for integration.

**4. Goal Location Planning**
- The optimizer returns goal positions and orientations, stored in Excel.
- These are directly fed into the simulation.
- A triggered subsystem ensures synchronization of data read and box arrival.


**5. Layered Packing Strategy**
- Boxes are placed layer by layer:

  - Boxes belonging to upper layers are temporarily stored on side platforms.
  - These boxes are picked up again for second-layer placement.
  - Some boxes are rejected to be a part of the pallet after running the optimization code and are placed on another box which would connect to conveyer.

**6. Trajectory Planning & Optimization**
  - Used Manipulator RRT to plan collision-free paths.
  - Boxes are programmed to hover 0.2 m above the goal position, then descend.
  - Initially tried intermediate waypoints but led to confusion in robot motion.

<br><br>

Step 1,2:
### Problem Setup—Data Collection and Reading

- The data of box dimensions was assumed to be known when the operators loaded the boxes on the conveyor.
- Basically, the boxes with known dimensions have a QR code or barcode that can be scanned in seconds and placed on the conveyor belt. As soon as these are scanned, their data will be added as an entry in an Excel sheet.
- This is a more practical approach than just keeping the boxes on the conveyor and using image processing techniques to read dimensions. This can lead to more errors, higher computational power and lower speed.

![Alt text](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/variable_box_generate.png)

- The ‘SpawnBoxonBench’ block was changed to have a ‘From Spreadsheet’ block, which would read the dimension data at trigger

<br><br>

Steps 3,4:
### Optimization Strategy

_The excel sheet has more boxes than what can be packed, which is necessary for optimization. The boxes that are rejected can be returned to the conveyor belt and packed in the next turn._

1. First, 1D optimization for the palette was tried out. The coordinates for the palette space were studied and a 2D bin packing code was written in python and results were obtained. 
2. Rotation was enabled along the z-axis. 
3. A greedy shelf-packing algorithm was used to start with. Python code can be found here: 2D bin packing 
4. The 3D version of the code was made with the following logic:
  - The boxes are arranged in descending order of their densities.
  - The ones with higher density were placed in the bottom layer since the denser ones are rigid and can hold more weight. (This strategy should work when there is   no very large difference in weights and dimensions.)
  - Another method was to arrange them in descending order of weights, but again, rigid, denser boxes may cause dents in bigger, less dense boxes.
  - The less dense boxes have higher surface area (assumed height is same), so this potentially gives them better chance of avoiding overhangs

**Constraints**

1. After arranging the boxes in descending order of planar density (P = Wt / L*B), they are divided into 60% and 40%, i.e., 60% of the boxes are given a chance to fit in the lower layer and 40% on the top. The numbers are 60-40 since rigid boxes were expected to be smaller in size and suited for my data.
Nonetheless, this parameter can be kept as a variable and solved dynamically after receiving data.
2. The code returns the arrangement for both the 1st and 2nd layers. These goal locs can then be passed to the simulink model for placements.
3. The 2nd layer arrangement follows a maximum 20% overhang rule, i.e., a minimum of 80% of their surface area must be supported for stability.

These codes were then converted into .m files and thus integrated in matlab itself. So the users just need to load an excel with some specified column/row format, run the matlab file and then run the simulink model.

![Alt text](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/packing_pic.png)

The code files can be found here:

1. 2D placements: [1 layer placements](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/rectanglesPlacement.m); Excel file associated: [Rectangles](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/Rectangles.xlsx) 
2. 3D placements: [3D placements](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/BoxesPlacementTwoLayers.m); Boxes data: [Boxes](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/Boxes.xlsx) 
3. Sheet obtained after 3D optimization: [3D box placements](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/box_placements_3D_10.xlsx)

<br><br>

Steps 4,5
### Goal Location feed and Layered Packing

The goal location obtained in a excel were fed dynamically to the Trajectory planner using a triggered sybsytem block. Goal location along with angle (0 or 90 degrees) was fed.
_The next question was, what if boxes to be placed on layer 2 arrive first?_

- The boxes had to be temporarily stored somewhere. A temporary storage platform was made, which would store all the boxes of layer two unless all boxes are finished spawning. (This box is green.)
- Another platform was made to reject boxes in a given packing after optimization is run. These boxes can be included in the next pallet. (This box is in red).
- To achieve this, two optimization codes run
  - Complete placements on palette (both layers)
  - For placements on the temporary platform
  - The placements on the temporary platform are done from the farthest point to the nearest and picked up in the opposite manner to avoid collisions.
- A triggered pickup location block was added (falling type) to dynamically feed the pickup locs. 
  - In Round 1, all pickup locations are same, i.e., on the spawn box
  - In Round 2, the pickup locations for layer 2 are their goal locations on temporary platform
- A MATLAB code was written to get an entire box pickup and goal schedule, which retained box IDs for temporary place and pickup.
    - Code [Pickup and drop scheduler](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/originalID.m)
    - Excel sheet obtained: [box pickup and drop schedule](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/box_pick_goal_schedule_14.xlsx)

**ID issue and solution**

- The box IDs for Pickup are triggered at falling instead of raising. Hence, pickup location and ID in 2nd round must start a row before in the sheet to be read properly. Hence, 2 sheets were generated in [box pickup and drop schedule](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/box_pick_goal_schedule_14.xlsx) using [Pickup and drop scheduler](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/originalID.m), where Sheet 2 has modified row and IDs with Pickup and IDs advancing by one row. This was tested and results were obtained correct.
- A sheet 3 is also generated for Dynamic box dim and location, which is for Collision avoidance, will be discussed in next section.

Sheet 1
![Sheet 1](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/sheet1_boxpicup14.png)
Sheet 2
![Sheet 2](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/Sheet2_boxpic.png)
      
<br><br>
Step 6:
### Trajectory Planning to avoid Collision

The trajectory planner plans waypoints that may be colliding with already placed boxes. The collision environment assumes the grasped box to be a part of the robot but doesn’t consider other boxes to be.



Hence, a strategy was made to avoid collisions:

- An intermediate waypoint was added in all trajectories - A point 0.2 m above the goal location.
-  So all boxes went to a point 0.2 m above their goal initially, thereby avoiding all the collisions of placed boxes.
-  After reaching the intermediate waypoint, the box would be lowered and placed there.
- Basically, two paths were calculated and interpolated to achieve this. The modified Manipulator code is here: [HelperPathPlanning Modified](https://github.com/Tanmaey45/Adaptive-Palletizer-/blob/main/helperPathPanning_Modified.m)


