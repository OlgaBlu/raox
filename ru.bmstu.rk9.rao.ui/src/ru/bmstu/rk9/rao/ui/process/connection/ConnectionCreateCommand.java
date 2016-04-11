package ru.bmstu.rk9.rao.ui.process.connection;

import org.eclipse.gef.commands.Command;

import ru.bmstu.rk9.rao.ui.process.node.BlockNode;

public class ConnectionCreateCommand extends Command {

	private BlockNode sourceBlockNode;
	private BlockNode targetBlockNode;
	private Connection connection;

	private String sourceDockName;
	private String targetDockName;

	public void setSource(BlockNode sourceBlockNode, String sourceDockName) {
		this.sourceBlockNode = sourceBlockNode;
		this.sourceDockName = sourceDockName;
	}

	public void setTarget(BlockNode targetBlockNode, String targetDockName) {
		this.targetBlockNode = targetBlockNode;
		this.targetDockName = targetDockName;
	}

	@Override
	public boolean canExecute() {
		if (sourceBlockNode == null || targetBlockNode == null)
			return false;
		if (sourceBlockNode.equals(targetBlockNode))
			return false;
		if (sourceBlockNode.getDocksCount(sourceDockName) > 0)
			return false;
		return true;
	}

	@Override
	public void execute() {
		connection = new Connection(sourceBlockNode, targetBlockNode, sourceDockName, targetDockName);
		connection.connect();
	}

	@Override
	public boolean canUndo() {
		if (sourceBlockNode == null || targetBlockNode == null || connection == null)
			return false;
		return true;
	}

	@Override
	public void undo() {
		connection.disconnect();
	}

	public final String getSourceDockName() {
		return sourceDockName;
	}

	public final String getTargetDockName() {
		return targetDockName;
	}
}
