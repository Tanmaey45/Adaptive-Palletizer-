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


**Step 1,2:**
## Problem Setup—Data Collection and Reading

- The data of box dimensions was assumed to be known when the operators loaded the boxes on the conveyor.
- Basically, the boxes with known dimensions have a QR code or barcode that can be scanned in seconds and placed on the conveyor belt. As soon as these are scanned, their data will be added as an entry in an Excel sheet.
- This is a more practical approach than just keeping the boxes on the conveyor and using image processing techniques to read dimensions. This can lead to more errors, higher computational power and lower speed.


