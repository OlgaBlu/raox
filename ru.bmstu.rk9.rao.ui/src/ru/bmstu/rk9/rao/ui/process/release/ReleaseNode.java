package ru.bmstu.rk9.rao.ui.process.release;

import java.util.Optional;

import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.swt.graphics.Color;

import ru.bmstu.rk9.rao.lib.resource.Resource;
import ru.bmstu.rk9.rao.lib.simulator.Simulator;
import ru.bmstu.rk9.rao.ui.process.BlockConverterInfo;
import ru.bmstu.rk9.rao.ui.process.ProcessColors;
import ru.bmstu.rk9.rao.ui.process.node.BlockNodeWithResource;

public class ReleaseNode extends BlockNodeWithResource {

	private static final long serialVersionUID = 1;

	public static final String DOCK_IN = "IN";
	public static final String DOCK_OUT = "OUT";
	private static Color foregroundColor = ProcessColors.BLOCK_COLOR;
	public static String name = "Release";

	public ReleaseNode() {
		super(foregroundColor.getRGB());
		setName(name);
		registerDock(DOCK_IN);
		registerDock(DOCK_OUT);
	}

	@Override
	public BlockConverterInfo createBlock() {
		Optional<Resource> optional = Simulator.getModelState().getAllResources().stream()
				.filter(resource -> resource.getName().equals(resourceName)).findAny();
		BlockConverterInfo releaseInfo = new BlockConverterInfo();
		if (!optional.isPresent()) {
			releaseInfo.isSuccessful = false;
			releaseInfo.errorMessage = "Resource name not selected";
			resourceName = "";
			return releaseInfo;
		}
		Resource seizedResource = optional.get();
		ru.bmstu.rk9.rao.lib.process.Release release = new ru.bmstu.rk9.rao.lib.process.Release(seizedResource);
		releaseInfo.setBlock(release);
		releaseInfo.inputDocks.put(DOCK_IN, release.getInputDock());
		releaseInfo.outputDocks.put(DOCK_OUT, release.getOutputDock());
		return releaseInfo;
	}

	@Override
	public void validateProperty(IResource file) throws CoreException {
		validateResource(file);
		validateConnections(file, 1, 1);
	}
}
