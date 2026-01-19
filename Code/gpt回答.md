下面我按“你这张图的样子”给你一个**更像原图的画法**（推荐：自己画半圆极坐标网格），再给一个“MATLAB 自带 polaraxes 的快捷版”。你只要把你的坐标喂进去就能出图。

---

## 你这张图的关键特征（决定怎么画）

从图上看，它不是完整圆形极坐标，而是：

1. **半圆**：只显示 **θ = -90° ~ +90°**（上半圆）
2. **0° 在正上方**（竖直向上是 0°）
3. 底边是一条水平线（y=0），底边上标着 **0 1 2 … 10**，左右对称（这是 **r 轴在 ±90° 上**的效果）
4. 网格很密（主网格 + 次网格），边界曲线粗黑线，内部可填充灰色

用 `polaraxes` 也能画，但**半圆+底部 r 刻度对称**这种“天线图/PVC 波束图”风格，最稳的是：**用普通 axes 自己画极坐标网格**。

---

# A. 最像原图的做法：自己画“半圆极坐标网格”（强烈推荐）

### 1）你的数据格式：θ(°) + r(米)

* `theta_deg`：角度（建议范围 -90~90）
* `r_m`：对应距离（米）

### 2）直接可用的完整函数（复制即可跑）

把下面保存为 `plot_pvc_beam.m`，然后调用。

```matlab
function plot_pvc_beam(theta_deg, r_m, varargin)
% plot_pvc_beam(theta_deg, r_m)
% 画“半圆极坐标 PVC波束图”，风格接近你图里的示例
%
% 输入:
%   theta_deg : 角度(°)，建议 -90~90（可以乱序）
%   r_m       : 半径/距离(米)，同长度
%
% 可选参数（name-value）:
%   'Rmax'        : 最大半径刻度，默认自动取 ceil(max(r_m))
%   'RMajorStep'  : 半径主刻度步进，默认 1
%   'RMinorStep'  : 半径次刻度步进，默认 0.5
%   'ThetaMajor'  : 角度主网格步进，默认 10
%   'ThetaMinor'  : 角度次网格步进，默认 5
%   'DoFill'      : 是否填充波束区域，默认 true
%   'Title'       : 标题，默认 'PVC波束图'
%   'UnitText'    : 单位文字，默认 '（单位：米）'

% ------------------ 参数解析 ------------------
p = inputParser;
p.addParameter('Rmax', [], @(x) isempty(x) || (isscalar(x) && x>0));
p.addParameter('RMajorStep', 1, @(x) isscalar(x) && x>0);
p.addParameter('RMinorStep', 0.5, @(x) isscalar(x) && x>0);
p.addParameter('ThetaMajor', 10, @(x) isscalar(x) && x>0);
p.addParameter('ThetaMinor', 5, @(x) isscalar(x) && x>0);
p.addParameter('DoFill', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('Title', 'PVC波束图', @(s) ischar(s) || isstring(s));
p.addParameter('UnitText', '（单位：米）', @(s) ischar(s) || isstring(s));
p.parse(varargin{:});
opt = p.Results;

theta_deg = theta_deg(:);
r_m       = r_m(:);

% ------------------ 数据清洗 ------------------
valid = isfinite(theta_deg) & isfinite(r_m);
theta_deg = theta_deg(valid);
r_m       = r_m(valid);

% 若角度不在[-90,90]，你可以选择裁剪或wrap，这里做裁剪
in = (theta_deg >= -90) & (theta_deg <= 90);
theta_deg = theta_deg(in);
r_m       = r_m(in);

% 按角度排序（很关键）
[theta_deg, idx] = sort(theta_deg);
r_m = r_m(idx);

% 自动Rmax
if isempty(opt.Rmax)
    opt.Rmax = max(1, ceil(max(r_m)));
end
Rmax = opt.Rmax;

% 闭合曲线（让填充更好看）
if theta_deg(1) ~= theta_deg(end) || r_m(1) ~= r_m(end)
    theta_deg(end+1) = theta_deg(1);
    r_m(end+1)       = r_m(1);
end

% ------------------ 坐标变换 ------------------
% 这里采用：0°朝上
% x = r*sin(theta), y = r*cos(theta)
th = deg2rad(theta_deg);
x  = r_m .* sin(th);
y  = r_m .* cos(th);

% ------------------ 画底图网格（半圆极坐标） ------------------
figure('Color','w');
ax = axes; hold(ax,'on'); axis(ax,'equal');
xlim(ax, [-Rmax Rmax]);
ylim(ax, [0 Rmax]);

% 网格颜色/粗细
majorColor = [0.55 0.55 0.55];
minorColor = [0.80 0.80 0.80];

% 1) 画圆弧：r = 0:RMinorStep:Rmax
theta_grid = deg2rad(-90:0.5:90);
rMinor = 0:opt.RMinorStep:Rmax;
for rr = rMinor
    xg = rr .* sin(theta_grid);
    yg = rr .* cos(theta_grid);

    isMajor = abs(mod(rr, opt.RMajorStep)) < 1e-9;
    if isMajor
        plot(ax, xg, yg, 'Color', majorColor, 'LineWidth', 0.9);
    else
        plot(ax, xg, yg, 'Color', minorColor, 'LineWidth', 0.6);
    end
end

% 2) 画径向线：theta = -90:ThetaMinor:90
for tt = -90:opt.ThetaMinor:90
    thh = deg2rad(tt);
    rr = [0 Rmax];
    xg = rr .* sin(thh);
    yg = rr .* cos(thh);

    isMajor = abs(mod(tt, opt.ThetaMajor)) < 1e-9;
    if isMajor
        plot(ax, xg, yg, 'Color', majorColor, 'LineWidth', 0.9);
    else
        plot(ax, xg, yg, 'Color', minorColor, 'LineWidth', 0.6);
    end
end

% 3) 外圈半圆边框加粗
xB = Rmax .* sin(theta_grid);
yB = Rmax .* cos(theta_grid);
plot(ax, xB, yB, 'k', 'LineWidth', 1.2);

% 4) 底边（y=0）加粗
plot(ax, [-Rmax Rmax], [0 0], 'k', 'LineWidth', 1.2);

% ------------------ 标注：角度刻度（外圈） ------------------
for tt = -90:opt.ThetaMajor:90
    thh = deg2rad(tt);
    rText = Rmax * 1.05;
    xt = rText * sin(thh);
    yt = rText * cos(thh);

    % 显示成 0~90（左右都用正数）符合你图
    label = sprintf('%d°', abs(tt));
    if tt == 0
        label = '0°';
    end

    text(ax, xt, yt, label, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', 'FontSize', 9);
end

% ------------------ 标注：半径刻度（底边左右对称） ------------------
% 在 y = -偏移处放数字
yoff = -Rmax * 0.04;
for rr = 0:opt.RMajorStep:Rmax
    % 左侧
    text(ax, -rr, yoff, sprintf('%g', rr), ...
        'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 9);
    % 右侧（rr=0时避免重复）
    if rr ~= 0
        text(ax, rr, yoff, sprintf('%g', rr), ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 9);
    end
end

% ------------------ 画波束边界 ------------------
% 填充（灰色）+ 边界（黑色粗线）
if opt.DoFill
    patch(ax, x, y, [0.90 0.90 0.90], 'EdgeColor','k', 'LineWidth',2);
else
    plot(ax, x, y, 'k', 'LineWidth', 2);
end

% ------------------ 标题/单位 ------------------
title(ax, opt.Title, 'FontSize', 11);
text(ax, Rmax*0.75, yoff*1.4, opt.UnitText, ...
    'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 9);

% 美化：去掉默认坐标轴刻度
ax.XTick = [];
ax.YTick = [];
box(ax,'off');
end
```

### 3）怎么调用

```matlab
% 假设你有两列数据：theta_deg, r_m
plot_pvc_beam(theta_deg, r_m, 'Rmax', 10, 'DoFill', true);
```

---

## B. 你只有 x,y 坐标怎么办？

如果你拿到的是边界点 (x,y)，先转成你这个定义的极坐标（0°朝上）：

```matlab
% x,y -> theta_deg, r_m （0°朝上）
r_m = hypot(x_m, y_m);
theta_deg = atan2d(x_m, y_m);  % 注意：atan2d( x, y ) 才能让0°在上

plot_pvc_beam(theta_deg, r_m, 'Rmax', 10);
```

---

## C. 如果你的点很稀疏/锯齿：插值平滑

角度点少时，建议插值到更密：

```matlab
% theta_deg, r_m 已有且在[-90,90]
[theta_deg, idx] = sort(theta_deg);
r_m = r_m(idx);

theta_dense = linspace(theta_deg(1), theta_deg(end), 400);
r_dense = interp1(theta_deg, r_m, theta_dense, 'pchip'); % pchip 比较平滑又不乱过冲

plot_pvc_beam(theta_dense, r_dense, 'Rmax', 10, 'DoFill', true);
```

---

# D. 快捷版：用 polaraxes（不追求“底部对称r刻度”时用）

如果你只想快点画出半圆极坐标曲线：

```matlab
theta = deg2rad(theta_deg(:));
r     = r_m(:);

[theta, idx] = sort(theta);
r = r(idx);

figure('Color','w');
ax = polaraxes; hold(ax,'on');

ax.ThetaZeroLocation = 'top';
ax.ThetaDir = 'clockwise';
ax.ThetaLim = [-90 90];
ax.RLim = [0 10];
ax.RTick = 0:1:10;
ax.ThetaTick = -90:10:90;
ax.ThetaTickLabel = string(abs(ax.ThetaTick));

polarplot(ax, theta, r, 'k', 'LineWidth', 2);
title(ax,'PVC波束图');
```

> 但注意：`polaraxes` 默认的 r 刻度位置/显示方式不一定能做到你图里“底边左右对称”，所以想**像原图**还是建议用上面的 A 方法。

---

## 你把坐标发我，我可以直接给你“可运行脚本”

为了我把刻度、Rmax、网格密度、填充效果一次调到最像，你只要贴一种就行：

* 形式1：两列（θ°, r_m）前 10 行
* 形式2：两列（x_m, y_m）前 10 行

我就能直接把 `plot_pvc_beam()` 的调用和参数替你设好（比如 Rmax=10、主次网格间距、是否填充、线宽等）。
