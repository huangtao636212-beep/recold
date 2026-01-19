%% pvc_beam_with_setup_demo.m
% 左：PVC波束图（半圆极坐标网格+包络+斜线填充）
% 右：测试示意图（PVC圆柱管 1000mm, φ75mm；探头高度H=37cm；PVC左右移动）

clear; clc; close all;

%% ========== 1) 你的PVC表格数据（单位：cm）==========
% 表：导轨距离(cm), 左方向(cm), 右方向(cm)
y_cm  = [0 10 50 90 130 170 180];
xL_cm = [0 -6 -31 -43 -48 -48 -22];
xR_cm = [0  5  30  41  40  50  34];

% 单位换算：cm -> m（与你示例图一致：单位：米）
cm2m = 0.01;
y  = y_cm  * cm2m;      % 前向距离(米)
xL = xL_cm * cm2m;      % 左边界(米，通常为负)
xR = xR_cm * cm2m;      % 右边界(米，通常为正)

%% ========== 2) 把左右边界拼成“闭合包络多边形” ==========
[xpoly, ypoly] = buildEnvelope(y, xL, xR);   % x=横向，y=前向（米）

%% ========== 3) 画“左图：半圆极坐标网格 + 波束包络 + 斜线填充” ==========
Rmax = 10; % 你截图底部是 0~10(米)，这里固定成10更像原图

fig = figure('Color','w');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

% --- 左子图 ---
ax1 = nexttile(1);
halfPolarGrid(ax1, Rmax, 1, 0.5, 10, 5);  % (Rmax, r主, r次, theta主, theta次)

% 先画包络边界（粗黑）
plot(ax1, xpoly, ypoly, 'k', 'LineWidth', 2);

% 斜线填充（网纹），尽量靠近你示例图
hatchAngle   = 45;     % 斜线角度（度）
hatchSpacing = 0.12;   % 斜线间距（米）——你想更密就调小，如0.08
hatchInPolygon(ax1, xpoly, ypoly, hatchAngle, hatchSpacing);

% 标题/单位
title(ax1, 'PVC波束图', 'FontSize', 11);
text(ax1, Rmax*0.78, -Rmax*0.12, '（单位：米）', 'HorizontalAlignment','left', 'FontSize', 9);

%% ========== 4) 画“右图：测试示意图”（可按你实际布置调整） ==========
ax2 = nexttile(2);
drawSetupSchematic(ax2);

%% ========== 5) 顶部说明文字（对应你截图的那行） ==========
sgtitle('（1）被测试物体为PVC材质白色圆柱管，高为1000mm、直径为75mm。', ...
    'FontSize', 18, 'FontWeight','bold');

%% ======================== 工具函数区 ========================

function [xpoly, ypoly] = buildEnvelope(y, xL, xR)
    % 输入：y, xL, xR 同长度（单位：m）
    y  = y(:);  xL = xL(:);  xR = xR(:);

    ok = isfinite(y) & isfinite(xL) & isfinite(xR);
    y = y(ok); xL = xL(ok); xR = xR(ok);

    % 按y排序，避免连线乱序
    [y, idx] = sort(y);
    xL = xL(idx);
    xR = xR(idx);

    % 右边界：y递增；左边界：y递减拼回去闭合
    xpoly = [xR; flipud(xL)];
    ypoly = [y;  flipud(y)];

    % 闭合
    if xpoly(1) ~= xpoly(end) || ypoly(1) ~= ypoly(end)
        xpoly(end+1) = xpoly(1);
        ypoly(end+1) = ypoly(1);
    end
end

function halfPolarGrid(ax, Rmax, rMajorStep, rMinorStep, thMajorStep, thMinorStep)
    % 自绘半圆极坐标网格：0°在上，左右±90°，底部对称r刻度
    axes(ax); cla(ax); hold(ax,'on'); axis(ax,'equal');
    xlim(ax, [-Rmax Rmax]);
    ylim(ax, [0 Rmax]);

    majorC = [0.55 0.55 0.55];
    minorC = [0.80 0.80 0.80];

    th = deg2rad(-90:0.5:90);

    % 圆弧网格
    rMinor = 0:rMinorStep:Rmax;
    for rr = rMinor
        x = rr.*sin(th);
        y = rr.*cos(th);
        isMajor = abs(mod(rr, rMajorStep)) < 1e-10;
        plot(ax, x, y, 'Color', tern(isMajor, majorC, minorC), ...
            'LineWidth', tern(isMajor, 0.9, 0.6));
    end

    % 径向网格
    for t = -90:thMinorStep:90
        thh = deg2rad(t);
        rr = [0 Rmax];
        x = rr.*sin(thh);
        y = rr.*cos(thh);
        isMajor = abs(mod(t, thMajorStep)) < 1e-10;
        plot(ax, x, y, 'Color', tern(isMajor, majorC, minorC), ...
            'LineWidth', tern(isMajor, 0.9, 0.6));
    end

    % 外圈 + 底边
    plot(ax, Rmax.*sin(th), Rmax.*cos(th), 'k', 'LineWidth', 1.2);
    plot(ax, [-Rmax Rmax], [0 0], 'k', 'LineWidth', 1.2);

    % 角度标注（外圈：左右显示 0~90）
    for t = -90:thMajorStep:90
        thh = deg2rad(t);
        rt  = Rmax*1.06;
        xt  = rt*sin(thh);
        yt  = rt*cos(thh);
        lab = sprintf('%d°', abs(t));
        if t==0, lab='0°'; end
        text(ax, xt, yt, lab, 'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', 'FontSize', 9);
    end

    % 半径标注（底边左右对称）
    yoff = -Rmax*0.04;
    for rr = 0:rMajorStep:Rmax
        text(ax, -rr, yoff, sprintf('%g', rr), ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 9);
        if rr~=0
            text(ax, rr, yoff, sprintf('%g', rr), ...
                'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 9);
        end
    end

    ax.XTick = []; ax.YTick = [];
    box(ax,'off');
end

function hatchInPolygon(ax, xpoly, ypoly, angleDeg, spacing)
    % 在多边形内画“斜线网纹”填充（不依赖外部库）
    % 思路：把坐标旋转，使网纹线变成“水平线”，逐条扫描并用 inpolygon 裁剪

    xpoly = xpoly(:); ypoly = ypoly(:);

    % 旋转矩阵：把世界坐标旋转 -angleDeg（让网纹线水平）
    a = deg2rad(angleDeg);
    R = [cos(a) -sin(a); sin(a) cos(a)];
    Ri = [cos(-a) -sin(-a); sin(-a) cos(-a)];

    P = [xpoly ypoly]*Ri'; % 旋转到“网纹坐标系”
    xr = P(:,1); yr = P(:,2);

    % 包围盒
    xmin = min(xr); xmax = max(xr);
    ymin = min(yr); ymax = max(yr);

    % 生成水平扫描线 y = const
    yLines = (floor(ymin/spacing)-1 : ceil(ymax/spacing)+1) * spacing;

    % 采样分辨率：越小越精细（但更耗时）
    dx = spacing/6;
    xs = xmin:dx:xmax;

    for yy = yLines
        % 在旋转坐标系中构造一条水平线上的点
        X = xs(:);
        Y = yy*ones(size(X));

        % 逆旋转回原坐标系
        XY = [X Y]*R';
        xw = XY(:,1);
        yw = XY(:,2);

        % 判断是否在多边形内
        inside = inpolygon(xw, yw, xpoly, ypoly);

        % 找 inside 连续段并画出来
        idx = find(inside);
        if isempty(idx), continue; end

        % 分段：不连续处断开
        breaks = [1; find(diff(idx) > 1)+1; numel(idx)+1];
        for k = 1:numel(breaks)-1
            seg = idx(breaks(k):breaks(k+1)-1);
            plot(ax, xw(seg), yw(seg), 'k', 'LineWidth', 0.8);
        end
    end
end

function drawSetupSchematic(ax)
    % 画一个“类似截图”的实验示意图（2D简化版）
    axes(ax); cla(ax); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');

    % 画地面/台面块（简化矩形）
    baseW = 6; baseH = 2.0;
    rectangle(ax, 'Position', [-3, -1, baseW, baseH], ...
        'EdgeColor','k', 'LineWidth', 1);

    % 探头（画个小圆+短杆）
    probeCenter = [0.0, 0.3];
    viscir(ax, probeCenter, 0.25, 1);
    plot(ax, [probeCenter(1), probeCenter(1)], [probeCenter(2), probeCenter(2)+0.6], 'k', 'LineWidth', 1);
    text(ax, probeCenter(1)-0.6, probeCenter(2)+0.9, '超声波探头', 'FontSize', 10);

    % PVC圆柱（用“矩形+椭圆顶”表示）
    pvcX = 2.3; pvcY = 0.2;
    pvcW = 0.6; pvcH = 3.0;
    rectangle(ax, 'Position', [pvcX, pvcY, pvcW, pvcH], 'EdgeColor','k', 'LineWidth', 1);
    % 顶部椭圆
    t = linspace(0, 2*pi, 200);
    ex = pvcX + pvcW/2 + (pvcW/2)*cos(t);
    ey = pvcY + pvcH + 0.15*sin(t);
    plot(ax, ex, ey, 'k', 'LineWidth', 1);

    text(ax, pvcX-0.4, pvcY+pvcH+0.5, 'PVC', 'FontSize', 10);
    text(ax, pvcX-0.6, pvcY+pvcH+0.2, 'φ75mm', 'FontSize', 10);

    % PVC高度标注 1000mm（用双向箭头）
    dimx = pvcX + pvcW + 0.6;
    plot(ax, [dimx dimx], [pvcY pvcY+pvcH], 'k', 'LineWidth', 1);
    arrow2(ax, [dimx, pvcY], [dimx, pvcY+pvcH]);
    arrow2(ax, [dimx, pvcY+pvcH], [dimx, pvcY]);
    text(ax, dimx+0.2, pvcY+pvcH/2, 'H=1000mm', 'Rotation', 90, 'FontSize', 10);

    % 探头高度标注 H=37cm（示意：从台面底到探头中心）
    dimx2 = -2.7;
    y0 = -1; y1 = probeCenter(2);
    plot(ax, [dimx2 dimx2], [y0 y1], 'k', 'LineWidth', 1);
    arrow2(ax, [dimx2, y0], [dimx2, y1]);
    arrow2(ax, [dimx2, y1], [dimx2, y0]);
    text(ax, dimx2-0.2, (y0+y1)/2, 'H=37cm', 'Rotation', 90, 'FontSize', 10, ...
        'HorizontalAlignment','right');

    % PVC相对探头左右移动（双向箭头）
    yArrow = 1.0;
    arrow2(ax, [0.7 yArrow], [2.1 yArrow]);
    arrow2(ax, [2.1 yArrow], [0.7 yArrow]);
    text(ax, 0.9, yArrow+0.3, 'PVC管平行于超声波探头左右移动', 'FontSize', 10, 'Rotation', 12);

    % 视野范围
    xlim(ax, [-3.5 4.0]);
    ylim(ax, [-1.5 4.2]);
end

function viscir(ax, c, r, lw)
    t = linspace(0,2*pi,200);
    plot(ax, c(1)+r*cos(t), c(2)+r*sin(t), 'k', 'LineWidth', lw);
end

function arrow2(ax, p1, p2)
    % 简易箭头（p1->p2），用线+小三角
    plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], 'k', 'LineWidth', 1);
    v = [p2(1)-p1(1), p2(2)-p1(2)];
    L = hypot(v(1),v(2));
    if L < 1e-9, return; end
    v = v / L;
    n = [-v(2), v(1)];
    headL = 0.15; headW = 0.08;
    p = [p2(1), p2(2)];
    tri = [p;
           p - headL*v + headW*n;
           p - headL*v - headW*n;
           p];
    plot(ax, tri(:,1), tri(:,2), 'k', 'LineWidth', 1);
end

function out = tern(cond, a, b)
    if cond, out = a; else, out = b; end
end
